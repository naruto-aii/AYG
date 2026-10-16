// Apple Ads Campaign Management API v5 の client secret JWT。
// aud は https://appleid.apple.com、iss は teamId、sub は clientId、ES256、kid は keyId。
// 秘密の値はエラー文にも残さない。

const oidEcPublicKey = Uint8Array.of(0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01);
const prime256v1Contents = Uint8Array.of(0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07);

type DerView = { tag: number; value: Uint8Array; end: number };

function concatBytes(parts: Uint8Array[]): Uint8Array {
  const size = parts.reduce((total, part) => total + part.length, 0);
  const out = new Uint8Array(size);
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}

function derLength(length: number): Uint8Array {
  if (length < 0x80) return Uint8Array.of(length);
  if (length <= 0xff) return Uint8Array.of(0x81, length);
  if (length <= 0xffff) return Uint8Array.of(0x82, (length >> 8) & 0xff, length & 0xff);
  throw new Error("unsupported private key");
}

function derTag(tag: number, content: Uint8Array): Uint8Array {
  const length = derLength(content.length);
  const out = new Uint8Array(1 + length.length + content.length);
  out[0] = tag;
  out.set(length, 1);
  out.set(content, 1 + length.length);
  return out;
}

function readDer(bytes: Uint8Array, offset: number): DerView {
  if (offset + 2 > bytes.length) throw new Error("unsupported private key");
  const tag = bytes[offset];
  let length = bytes[offset + 1];
  let start = offset + 2;
  if (length & 0x80) {
    const count = length & 0x7f;
    if (count === 0 || count > 2 || start + count > bytes.length) throw new Error("unsupported private key");
    length = 0;
    for (let index = 0; index < count; index++) length = (length << 8) | bytes[start + index];
    start += count;
  }
  const end = start + length;
  if (end > bytes.length) throw new Error("unsupported private key");
  return { tag, value: bytes.subarray(start, end), end };
}

function sameBytes(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let index = 0; index < left.length; index++) mismatch |= left[index] ^ right[index];
  return mismatch === 0;
}

function assertPrime256v1(sec1: Uint8Array): void {
  const sequence = readDer(sec1, 0);
  if (sequence.tag !== 0x30 || sequence.end !== sec1.length) throw new Error("unsupported private key");
  const version = readDer(sequence.value, 0);
  if (version.tag !== 0x02 || version.value.length !== 1 || version.value[0] !== 1) {
    throw new Error("unsupported private key");
  }
  const privateKey = readDer(sequence.value, version.end);
  if (privateKey.tag !== 0x04 || privateKey.value.length !== 32) throw new Error("unsupported private key");
  if (privateKey.end >= sequence.value.length) throw new Error("unsupported private key");
  const parameters = readDer(sequence.value, privateKey.end);
  if (parameters.tag !== 0xa0) throw new Error("unsupported private key");
  const oid = readDer(parameters.value, 0);
  if (oid.tag !== 0x06 || oid.end !== parameters.value.length || !sameBytes(oid.value, prime256v1Contents)) {
    throw new Error("unsupported private key");
  }
}

/// openssl ecparam -genkey -name prime256v1 の SEC1 を、WebCrypto が読む PKCS#8 にする。
export function sec1ToPkcs8(sec1: Uint8Array): Uint8Array {
  assertPrime256v1(sec1);
  const algorithm = derTag(0x30, concatBytes([oidEcPublicKey, derTag(0x06, prime256v1Contents)]));
  const version = Uint8Array.of(0x02, 0x01, 0x00);
  return derTag(0x30, concatBytes([version, algorithm, derTag(0x04, sec1)]));
}

function pemBytes(pem: string): Uint8Array {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  if (!body) throw new Error("unsupported private key");
  let binary = "";
  try {
    binary = atob(body);
  } catch {
    throw new Error("unsupported private key");
  }
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

function isPkcs8(der: Uint8Array): boolean {
  try {
    const sequence = readDer(der, 0);
    if (sequence.tag !== 0x30 || sequence.end !== der.length) return false;
    const version = readDer(sequence.value, 0);
    return version.tag === 0x02 && version.value.length === 1 && version.value[0] === 0;
  } catch {
    return false;
  }
}

/// PKCS#8（BEGIN PRIVATE KEY）と SEC1（BEGIN EC PRIVATE KEY）の両方を受ける。
export function pemToPkcs8(pem: string): Uint8Array {
  const normalized = pem.replaceAll("\\n", "\n").trim();
  const der = pemBytes(normalized);
  if (/BEGIN PRIVATE KEY/.test(normalized) || isPkcs8(der)) {
    if (!isPkcs8(der)) throw new Error("unsupported private key");
    return der;
  }
  return sec1ToPkcs8(der);
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function utf8(value: string): Uint8Array<ArrayBuffer> {
  return new TextEncoder().encode(value);
}

function copyBuffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(copy).set(bytes);
  return copy;
}

/// 有効期限は 20 分。アクセストークンは別途、短いものを取りにいく。
export async function signAppleAdsClientSecret(input: {
  clientId: string;
  teamId: string;
  keyId: string;
  pkcs8: Uint8Array;
  nowSeconds: number;
}): Promise<string> {
  const key = await crypto.subtle.importKey(
    "pkcs8",
    copyBuffer(input.pkcs8),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const header = base64Url(utf8(JSON.stringify({ alg: "ES256", kid: input.keyId, typ: "JWT" })));
  const payload = base64Url(utf8(JSON.stringify({
    iss: input.teamId,
    sub: input.clientId,
    aud: "https://appleid.apple.com",
    iat: input.nowSeconds,
    exp: input.nowSeconds + 20 * 60,
  })));
  const signed = new Uint8Array(await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    utf8(`${header}.${payload}`),
  ));
  if (signed.length !== 64) throw new Error("unsupported private key");
  return `${header}.${payload}.${base64Url(signed)}`;
}
