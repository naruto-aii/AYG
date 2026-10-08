// 重いJPEGを、その階層の長辺まで縮める。読めないときは元のバイトを返す。

import { jpegBytesFromBase64 } from "./validate.ts";

type JpegDecoded = { width: number; height: number; data: Uint8Array };
type JpegApi = {
  decode: (
    data: Uint8Array,
    opts?: { useTArray?: boolean; formatAsRGBA?: boolean },
  ) => JpegDecoded;
  encode: (
    image: { data: Uint8Array; width: number; height: number },
    quality?: number,
  ) => { data: Uint8Array };
};

async function jpegApi(): Promise<JpegApi> {
  const loaded = await import("npm:jpeg-js@0.4.4");
  return loaded as JpegApi;
}

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

export function downscaleRgba(
  source: JpegDecoded,
  maxEdge: number,
): JpegDecoded | null {
  const long = Math.max(source.width, source.height);
  if (maxEdge < 1 || long <= maxEdge || source.width < 1 || source.height < 1) {
    return null;
  }
  const width = Math.max(1, Math.round(source.width * maxEdge / long));
  const height = Math.max(1, Math.round(source.height * maxEdge / long));
  const dst = new Uint8Array(width * height * 4);
  for (let y = 0; y < height; y++) {
    const sy = Math.min(source.height - 1, Math.floor(y * source.height / height));
    for (let x = 0; x < width; x++) {
      const sx = Math.min(source.width - 1, Math.floor(x * source.width / width));
      const from = (sy * source.width + sx) * 4;
      const to = (y * width + x) * 4;
      dst[to] = source.data[from];
      dst[to + 1] = source.data[from + 1];
      dst[to + 2] = source.data[from + 2];
      dst[to + 3] = source.data[from + 3];
    }
  }
  return { width, height, data: dst };
}

export async function downscaleJpeg(bytes: Uint8Array, maxEdge: number): Promise<Uint8Array> {
  try {
    const api = await jpegApi();
    const decoded = api.decode(bytes, { useTArray: true, formatAsRGBA: true });
    const scaled = downscaleRgba(decoded, maxEdge);
    if (scaled == null) {
      return bytes;
    }
    const encoded = api.encode(scaled, 80);
    if (!encoded.data || encoded.data.length < 3) {
      return bytes;
    }
    return encoded.data;
  } catch {
    return bytes;
  }
}

export async function jpegBase64WithinEdge(base64: string, maxEdge: number): Promise<string> {
  const cleaned = base64.replace(/\s/g, "");
  const bytes = jpegBytesFromBase64(cleaned);
  if (!bytes) {
    return cleaned;
  }
  const scaled = await downscaleJpeg(bytes, maxEdge);
  if (scaled === bytes) {
    return cleaned;
  }
  return bytesToBase64(scaled);
}
