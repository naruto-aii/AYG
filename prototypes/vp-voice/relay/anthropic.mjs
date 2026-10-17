function stripExtras(body) {
  const next = { ...body };
  delete next.thinking;
  delete next.output_config;
  if (Array.isArray(next.system)) {
    next.system = next.system.map((block) => {
      const copy = { ...block };
      delete copy.cache_control;
      return copy;
    });
  }
  if (Array.isArray(next.tools)) {
    next.tools = next.tools.map((tool) => {
      const copy = { ...tool };
      delete copy.cache_control;
      return copy;
    });
  }
  return next;
}

function cleanBlock(block) {
  if (!block) return null;
  if (block.type === "text") {
    if (!block.text) return null;
    return { type: "text", text: block.text };
  }
  if (block.type === "tool_use") {
    return {
      type: "tool_use",
      id: block.id,
      name: block.name,
      input: block.input || {},
    };
  }
  if (block.type === "thinking") {
    const out = { type: "thinking", thinking: block.thinking || "" };
    if (block.signature) out.signature = block.signature;
    return out;
  }
  return null;
}

export async function readAnthropicStream(response, onText) {
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buf = "";
  const blocks = [];
  let stopReason = null;
  const usage = { input: 0, output: 0, cacheWrite: 0, cacheRead: 0 };
  const textParts = [];

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buf += decoder.decode(value, { stream: true });
    const lines = buf.split("\n");
    buf = lines.pop() ?? "";
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed.startsWith("data:")) continue;
      const data = trimmed.slice(5).trim();
      if (!data || data === "[DONE]") continue;
      let event;
      try {
        event = JSON.parse(data);
      } catch {
        continue;
      }
      if (event.type === "message_start") {
        const u = event.message?.usage || {};
        usage.input += u.input_tokens || 0;
        usage.cacheWrite += u.cache_creation_input_tokens || 0;
        usage.cacheRead += u.cache_read_input_tokens || 0;
      } else if (event.type === "content_block_start") {
        const block = { ...event.content_block };
        if (block.type === "tool_use") block._json = "";
        if (block.type === "text") block.text = block.text || "";
        if (block.type === "thinking") block.thinking = block.thinking || "";
        blocks[event.index] = block;
      } else if (event.type === "content_block_delta") {
        const block = blocks[event.index];
        const delta = event.delta;
        if (!block || !delta) continue;
        if (delta.type === "text_delta") {
          block.text += delta.text;
          textParts.push(delta.text);
          onText?.(delta.text);
        } else if (delta.type === "thinking_delta") {
          block.thinking += delta.thinking || "";
        } else if (delta.type === "signature_delta") {
          block.signature = (block.signature || "") + (delta.signature || "");
        } else if (delta.type === "input_json_delta") {
          block._json = (block._json || "") + (delta.partial_json || "");
        }
      } else if (event.type === "content_block_stop") {
        const block = blocks[event.index];
        if (block?.type === "tool_use") {
          try {
            block.input = block._json ? JSON.parse(block._json) : block.input || {};
          } catch {
            block.input = {};
          }
          delete block._json;
        }
      } else if (event.type === "message_delta") {
        stopReason = event.delta?.stop_reason ?? stopReason;
        usage.output += event.usage?.output_tokens || 0;
      } else if (event.type === "error") {
        throw new Error(event.error?.message || "Anthropicのストリームが失敗しました");
      }
    }
  }

  return {
    blocks: blocks.map(cleanBlock).filter(Boolean),
    stopReason,
    usage,
    text: textParts.join(""),
  };
}

export async function streamMessage({ apiKey, baseUrl, body, signal, retried = false, onText }) {
  const send = async (payload) => {
    const response = await fetch(`${baseUrl.replace(/\/$/, "")}/v1/messages`, {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
      signal,
    });
    if (response.status === 400) {
      const errText = await response.text();
      if (!retried && /output_config|thinking|cache_control|effort/i.test(errText)) {
        return streamMessage({
          apiKey,
          baseUrl,
          body: stripExtras(payload),
          signal,
          retried: true,
          onText,
        });
      }
      throw new Error(errText.slice(0, 300));
    }
    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`Anthropic ${response.status}: ${errText.slice(0, 300)}`);
    }
    return readAnthropicStream(response, onText);
  };
  return send(body);
}
