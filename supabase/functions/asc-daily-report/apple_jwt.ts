// App Store Connect の JWT。store_live.ts は store_import.ts を読むので、ここへ必要な部分だけを写す。
// 既存ファイルは変えない。秘密は戻り値以外に出さない。

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

export function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

/// 有効期限は 20 分未満。
export async function signAppleJwt(input: {
  issuer: string;
  keyId: string;
  pkcs8: ArrayBuffer;
  nowSeconds: number;
}): Promise<string> {
  const key = await crypto.subtle.importKey(
    "pkcs8",
    input.pkcs8,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const header = base64Url(
    new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: input.keyId, typ: "JWT" })),
  );
  const payload = base64Url(
    new TextEncoder().encode(JSON.stringify({
      iss: input.issuer,
      iat: input.nowSeconds,
      exp: input.nowSeconds + 19 * 60,
      aud: "appstoreconnect-v1",
    })),
  );
  const signed = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  );
  return `${header}.${payload}.${base64Url(new Uint8Array(signed))}`;
}
