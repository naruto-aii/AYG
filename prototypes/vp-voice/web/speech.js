export function pullSentences(buffer, flush) {
  const sentences = [];
  let rest = String(buffer || "").replace(/\s+/g, " ");
  const matcher = /.*?[。！？!?]/;
  while (rest.length) {
    const match = rest.match(matcher);
    if (!match || match.index === undefined) break;
    const sentence = match[0].trim();
    if (sentence) sentences.push(sentence);
    rest = rest.slice(match.index + match[0].length);
  }
  if (rest.length > 42) {
    const comma = rest.search(/[、，]/);
    if (comma >= 10) {
      sentences.push(rest.slice(0, comma + 1).trim());
      rest = rest.slice(comma + 1);
    }
  }
  if (flush && rest.trim()) {
    sentences.push(rest.trim());
    rest = "";
  }
  return { sentences, rest };
}

export function createSpeech({ onSpeaking } = {}) {
  const synth = typeof window !== "undefined" ? window.speechSynthesis : null;
  let queue = [];
  let voice = null;
  let token = 0;
  let pumping = false;
  let ignoreUntil = 0;

  function pickVoice() {
    const voices = synth?.getVoices?.() || [];
    const score = (item) => {
      const name = `${item.name} ${item.lang}`.toLowerCase();
      let value = 0;
      if (item.lang.toLowerCase().startsWith("ja")) value += 50;
      if (/kyoko|nanami|haruka|ayumi|sayaka|o-ren|female|女/.test(name)) value += 40;
      if (/google 日本語/.test(name)) value += 18;
      if (/male|男|ichiro/.test(name)) value -= 30;
      return value;
    };
    voice = voices.slice().sort((a, b) => score(b) - score(a))[0] || null;
  }

  if (synth) {
    pickVoice();
    synth.addEventListener?.("voiceschanged", pickVoice);
  }

  function speakOne(text, options = {}) {
    return new Promise((resolve) => {
      if (!synth || !text.trim()) {
        resolve();
        return;
      }
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = "ja-JP";
      utterance.pitch = options.pitch ?? 1.34;
      utterance.rate = options.rate ?? 1.06;
      utterance.volume = options.volume ?? 1;
      if (voice) utterance.voice = voice;
      const mine = token;
      utterance.onstart = () => {
        if (mine === token && !options.quiet) onSpeaking?.(true);
      };
      utterance.onend = () => {
        if (mine === token && !options.quiet) onSpeaking?.(false);
        resolve();
      };
      utterance.onerror = () => {
        if (mine === token && !options.quiet) onSpeaking?.(false);
        resolve();
      };
      synth.speak(utterance);
    });
  }

  async function pump() {
    if (pumping) return;
    pumping = true;
    while (queue.length) {
      const next = queue.shift();
      const mine = token;
      await speakOne(next);
      if (mine !== token) break;
    }
    pumping = false;
    onSpeaking?.(false);
  }

  return {
    unlock() {
      if (!synth) return;
      const utterance = new SpeechSynthesisUtterance(" ");
      utterance.volume = 0;
      utterance.lang = "ja-JP";
      synth.speak(utterance);
    },
    cancel() {
      token += 1;
      queue = [];
      synth?.cancel();
      onSpeaking?.(false);
    },
    enqueue(text) {
      const clean = String(text || "").trim();
      if (!clean) return;
      queue.push(clean);
      pump();
    },
    say(text, options) {
      return speakOne(String(text || ""), options);
    },
    aizuchi(text) {
      ignoreUntil = Date.now() + 900;
      return speakOne(text, { volume: 0.35, pitch: 1.46, rate: 1.14, quiet: true });
    },
    get ignoreUntil() {
      return ignoreUntil;
    },
    describeVoice() {
      return voice ? `${voice.name}（${voice.lang}）` : "ブラウザの日本語音声";
    },
  };
}
