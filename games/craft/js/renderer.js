import { HEIGHT, SIZE } from "./constants.js";
import { blockOf, tileOf } from "./blocks.js";
import { TILE } from "./tiles.js";
import { meshBlockOutline } from "./mesher.js";

const VS = `#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
layout(location=1) in vec2 aUv;
layout(location=2) in float aTile;
layout(location=3) in vec3 aLight;
uniform mat4 uVP;
uniform vec3 uCam;
out vec2 vUv;
out float vTile;
out vec3 vLight;
out float vDist;
out vec3 vWorld;
void main() {
  vWorld = aPos;
  gl_Position = uVP * vec4(aPos, 1.0);
  vUv = aUv;
  vTile = aTile;
  vLight = aLight;
  vDist = length(aPos - uCam);
}`;

const FS = `#version 300 es
precision highp float;
uniform sampler2D uAtlas;
uniform float uCols;
uniform float uRows;
uniform float uSky;
uniform vec3 uFog;
uniform float uFogNear;
uniform float uFogFar;
uniform float uCutout;
uniform float uAlpha;
in vec2 vUv;
in float vTile;
in vec3 vLight;
in float vDist;
out vec4 outColor;
void main() {
  float col = mod(vTile + 0.5, uCols);
  float row = floor((vTile + 0.5) / uCols);
  vec2 f = fract(vUv);
  vec2 uv = (vec2(col, row) + (0.5 + f * 15.0) / 16.0) / vec2(uCols, uRows);
  vec4 tex = texture(uAtlas, uv);
  if (uCutout > 0.5 && tex.a < 0.35) discard;
  float light = max(vLight.y, vLight.x * uSky);
  light = clamp(light, 0.05, 1.0);
  vec3 color = tex.rgb * light * vLight.z;
  float fog = smoothstep(uFogNear, uFogFar, vDist);
  color = mix(color, uFog, fog);
  float alpha = tex.a * uAlpha;
  if (alpha < 0.02) discard;
  outColor = vec4(color, alpha);
}`;

const FLUID_VS = `#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
layout(location=1) in vec2 aUv;
layout(location=2) in float aTile;
layout(location=3) in vec3 aLight;
uniform mat4 uVP;
uniform vec3 uCam;
out vec3 vWorld;
out vec3 vLight;
out float vDist;
void main() {
  vWorld = aPos;
  gl_Position = uVP * vec4(aPos, 1.0);
  vLight = aLight;
  vDist = length(aPos - uCam);
}`;

const FLUID_FS = `#version 300 es
precision highp float;
uniform sampler2D uTex;
uniform float uTime;
uniform float uSky;
uniform vec3 uFog;
uniform float uFogNear;
uniform float uFogFar;
uniform vec3 uTint;
uniform float uAlpha;
in vec3 vWorld;
in vec3 vLight;
in float vDist;
out vec4 outColor;
void main() {
  vec2 uv = vWorld.xz * 0.22 + vec2(uTime * 0.05, uTime * 0.02);
  vec4 tex = texture(uTex, uv);
  float light = max(vLight.y, vLight.x * uSky);
  light = clamp(light, 0.08, 1.0);
  vec3 color = tex.rgb * uTint * light * vLight.z;
  float fog = smoothstep(uFogNear, uFogFar, vDist);
  color = mix(color, uFog, fog);
  outColor = vec4(color, uAlpha);
}`;

const SKY_VS = `#version 300 es
precision highp float;
layout(location=0) in vec2 aPos;
out vec2 vClip;
void main() {
  vClip = aPos;
  gl_Position = vec4(aPos, 1.0, 1.0);
}`;

const SKY_FS = `#version 300 es
precision highp float;
in vec2 vClip;
uniform vec3 uTop;
uniform vec3 uHorizon;
uniform vec3 uBottom;
uniform vec3 uForward;
uniform vec3 uRight;
uniform vec3 uUp;
uniform vec3 uSun;
uniform float uDay;
uniform float uFovX;
uniform float uFovY;
out vec4 outColor;
void main() {
  vec3 dir = normalize(uForward + uRight * vClip.x * uFovX + uUp * vClip.y * uFovY);
  float h = dir.y;
  vec3 col = mix(uHorizon, h > 0.0 ? uTop : uBottom, clamp(abs(h) * 1.35, 0.0, 1.0));
  float sun = pow(max(dot(dir, normalize(uSun)), 0.0), 220.0);
  float glow = pow(max(dot(dir, normalize(uSun)), 0.0), 6.0);
  col += vec3(1.0, 0.95, 0.8) * sun;
  col += vec3(1.0, 0.55, 0.25) * glow * (1.0 - smoothstep(0.05, 0.55, uDay)) * 0.55;
  float moon = pow(max(dot(dir, normalize(-uSun)), 0.0), 320.0);
  col += vec3(0.85, 0.9, 1.0) * moon * (1.0 - uDay);
  outColor = vec4(col, 1.0);
}`;

const SOLID_VS = `#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aCol;
uniform mat4 uVP;
out vec3 vCol;
void main() {
  gl_Position = uVP * vec4(aPos, 1.0);
  vCol = aCol;
}`;

const SOLID_FS = `#version 300 es
precision highp float;
in vec3 vCol;
uniform float uAlpha;
out vec4 outColor;
void main() { outColor = vec4(vCol, uAlpha); }`;

const STAR_VS = `#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
uniform mat4 uVP;
uniform float uPoint;
void main() {
  gl_Position = uVP * vec4(aPos, 1.0);
  gl_PointSize = uPoint;
}`;

const STAR_FS = `#version 300 es
precision highp float;
uniform float uAlpha;
out vec4 outColor;
void main() {
  vec2 p = gl_PointCoord * 2.0 - 1.0;
  if (dot(p, p) > 1.0) discard;
  outColor = vec4(0.92, 0.95, 1.0, uAlpha);
}`;

const CLOUD_VS = `#version 300 es
precision highp float;
layout(location=0) in vec2 aPos;
uniform vec3 uCam;
uniform float uY;
uniform float uSize;
uniform mat4 uVP;
out vec2 vUv;
void main() {
  vec3 world = vec3(uCam.x + aPos.x * uSize, uY, uCam.z + aPos.y * uSize);
  vUv = world.xz * 0.012;
  gl_Position = uVP * vec4(world, 1.0);
}`;

const CLOUD_FS = `#version 300 es
precision highp float;
uniform sampler2D uTex;
uniform float uTime;
uniform float uDay;
uniform vec3 uFog;
in vec2 vUv;
out vec4 outColor;
void main() {
  vec4 tex = texture(uTex, vUv + vec2(uTime * 0.004, 0.0));
  if (tex.a < 0.2) discard;
  vec3 col = mix(vec3(0.55, 0.6, 0.7), vec3(1.0), uDay);
  col = mix(col, uFog, 0.15);
  outColor = vec4(col, tex.a * 0.82);
}`;

function compile(gl, type, src) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, src);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    throw new Error(gl.getShaderInfoLog(shader) || "shader");
  }
  return shader;
}

function program(gl, vs, fs) {
  const p = gl.createProgram();
  gl.attachShader(p, compile(gl, gl.VERTEX_SHADER, vs));
  gl.attachShader(p, compile(gl, gl.FRAGMENT_SHADER, fs));
  gl.linkProgram(p);
  if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p) || "link");
  return p;
}

// WebKit keeps vertex-attrib enables on the default VAO. A later drawArrays
// that only binds attribute 0 then fails, and VAO draws can miss their buffers.
// Bind the buffer and enable only the attributes this draw uses.
function useAttribs(gl, buffer, layout) {
  if (gl.bindVertexArray) gl.bindVertexArray(null);
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
  for (let i = 0; i < 4; i++) gl.disableVertexAttribArray(i);
  for (const [index, size, stride, offset] of layout) {
    gl.enableVertexAttribArray(index);
    gl.vertexAttribPointer(index, size, gl.FLOAT, false, stride, offset);
  }
}

const CHUNK_ATTRIBS = [[0, 3, 36, 0], [1, 2, 36, 12], [2, 1, 36, 20], [3, 3, 36, 24]];

function perspective(out, fov, aspect, near, far) {
  out.fill(0);
  const f = 1 / Math.tan(fov * 0.5);
  out[0] = f / aspect;
  out[5] = f;
  out[10] = (far + near) / (near - far);
  out[11] = -1;
  out[14] = (2 * far * near) / (near - far);
}

function lookAt(out, eye, target, up) {
  let zx = eye[0] - target[0];
  let zy = eye[1] - target[1];
  let zz = eye[2] - target[2];
  let len = Math.hypot(zx, zy, zz) || 1;
  zx /= len; zy /= len; zz /= len;
  let xx = up[1] * zz - up[2] * zy;
  let xy = up[2] * zx - up[0] * zz;
  let xz = up[0] * zy - up[1] * zx;
  len = Math.hypot(xx, xy, xz) || 1;
  xx /= len; xy /= len; xz /= len;
  const yx = zy * xz - zz * xy;
  const yy = zz * xx - zx * xz;
  const yz = zx * xy - zy * xx;
  out[0] = xx; out[1] = yx; out[2] = zx; out[3] = 0;
  out[4] = xy; out[5] = yy; out[6] = zy; out[7] = 0;
  out[8] = xz; out[9] = yz; out[10] = zz; out[11] = 0;
  out[12] = -(xx * eye[0] + xy * eye[1] + xz * eye[2]);
  out[13] = -(yx * eye[0] + yy * eye[1] + yz * eye[2]);
  out[14] = -(zx * eye[0] + zy * eye[1] + zz * eye[2]);
  out[15] = 1;
}

function multiply(out, a, b) {
  for (let c = 0; c < 4; c++) {
    for (let r = 0; r < 4; r++) {
      out[c * 4 + r] = a[r] * b[c * 4] + a[4 + r] * b[c * 4 + 1] + a[8 + r] * b[c * 4 + 2] + a[12 + r] * b[c * 4 + 3];
    }
  }
}

function planesFrom(vp) {
  const row = (i) => [vp[i], vp[4 + i], vp[8 + i], vp[12 + i]];
  const combine = (sign, r1) => {
    const a = row(3);
    const b = row(r1);
    const p = [a[0] + sign * b[0], a[1] + sign * b[1], a[2] + sign * b[2], a[3] + sign * b[3]];
    const len = Math.hypot(p[0], p[1], p[2]) || 1;
    return p.map((v) => v / len);
  };
  return [combine(1, 0), combine(-1, 0), combine(1, 1), combine(-1, 1), combine(1, 2), combine(-1, 2)];
}

function culled(planes, min, max) {
  for (const p of planes) {
    const x = p[0] >= 0 ? max[0] : min[0];
    const y = p[1] >= 0 ? max[1] : min[1];
    const z = p[2] >= 0 ? max[2] : min[2];
    if (p[0] * x + p[1] * y + p[2] * z + p[3] < 0) return true;
  }
  return false;
}

function makeBuffer(gl, target, data, usage) {
  const buf = gl.createBuffer();
  gl.bindBuffer(target, buf);
  gl.bufferData(target, data, usage || gl.STATIC_DRAW);
  return buf;
}

export class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.gl = canvas.getContext("webgl2", {
      antialias: false,
      alpha: false,
      depth: true,
      powerPreference: "high-performance",
    });
    this.ok = !!this.gl;
    this.chunks = new Map();
    this.vp = new Float32Array(16);
    this.proj = new Float32Array(16);
    this.view = new Float32Array(16);
    this.tmp = new Float32Array(16);
    this.dynamic = { verts: [], indices: [] };
    if (this.ok) this.init();
  }

  init() {
    const gl = this.gl;
    this.chunkProg = program(gl, VS, FS);
    this.fluidProg = program(gl, FLUID_VS, FLUID_FS);
    this.skyProg = program(gl, SKY_VS, SKY_FS);
    this.solidProg = program(gl, SOLID_VS, SOLID_FS);
    this.starProg = program(gl, STAR_VS, STAR_FS);
    this.cloudProg = program(gl, CLOUD_VS, CLOUD_FS);
    this.skyBuf = makeBuffer(gl, gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]));
    const stars = [];
    for (let i = 0; i < 280; i++) {
      const theta = Math.random() * Math.PI * 2;
      const phi = Math.acos(Math.random() * 2 - 1);
      const r = 180;
      stars.push(Math.sin(phi) * Math.cos(theta) * r, Math.cos(phi) * r, Math.sin(phi) * Math.sin(theta) * r);
    }
    this.starCount = stars.length / 3;
    this.starBuf = makeBuffer(gl, gl.ARRAY_BUFFER, new Float32Array(stars));
    this.cloudBuf = makeBuffer(gl, gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]));
    this.outline = meshBlockOutline();
    this.outlineBuf = makeBuffer(gl, gl.ARRAY_BUFFER, this.outline);
    gl.enable(gl.DEPTH_TEST);
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.BACK);
  }

  setTextures(tex) {
    const gl = this.gl;
    const upload = (source, wrap) => {
      const t = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, t);
      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, source);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, wrap);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, wrap);
      return t;
    };
    this.atlas = upload(tex.atlas, gl.CLAMP_TO_EDGE);
    this.waterTex = upload(tex.water, gl.REPEAT);
    this.lavaTex = upload(tex.lava, gl.REPEAT);
    this.cloudTex = upload(tex.cloud, gl.REPEAT);
    this.cols = tex.cols;
    this.rows = tex.rows;
  }

  resize(dpr) {
    const w = Math.max(1, Math.floor(this.canvas.clientWidth * dpr));
    const h = Math.max(1, Math.floor(this.canvas.clientHeight * dpr));
    if (this.canvas.width !== w || this.canvas.height !== h) {
      this.canvas.width = w;
      this.canvas.height = h;
    }
    this.gl.viewport(0, 0, w, h);
  }

  upload(key, mesh) {
    const gl = this.gl;
    let rec = this.chunks.get(key);
    if (!rec) {
      rec = {};
      this.chunks.set(key, rec);
    }
    for (const pass of ["opaque", "cutout", "water", "lava"]) {
      const part = mesh[pass];
      if (!rec[pass]) rec[pass] = { vbo: gl.createBuffer(), ibo: gl.createBuffer(), count: 0 };
      const slot = rec[pass];
      if (gl.bindVertexArray) gl.bindVertexArray(null);
      gl.bindBuffer(gl.ARRAY_BUFFER, slot.vbo);
      gl.bufferData(gl.ARRAY_BUFFER, part.verts, gl.DYNAMIC_DRAW);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, slot.ibo);
      gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, part.indices, gl.DYNAMIC_DRAW);
      slot.count = part.indices.length;
    }
  }

  clearMeshes() {
    for (const key of [...this.chunks.keys()]) this.drop(key);
  }

  drop(key) {
    const gl = this.gl;
    const rec = this.chunks.get(key);
    if (!rec) return;
    for (const pass of ["opaque", "cutout", "water", "lava"]) {
      const slot = rec[pass];
      if (!slot) continue;
      gl.deleteBuffer(slot.vbo);
      gl.deleteBuffer(slot.ibo);
      if (slot.vao) gl.deleteVertexArray(slot.vao);
    }
    this.chunks.delete(key);
  }

  render(frame) {
    const gl = this.gl;
    const { camera, sky, fogNear, fogFar, skyFactor, time, target, crack, entities, particles, held, day } = frame;
    this.resize(frame.dpr || 1);
    const aspect = this.canvas.width / Math.max(1, this.canvas.height);
    const fov = (camera.fov * Math.PI) / 180;
    perspective(this.proj, fov, aspect, 0.08, 420);
    const eye = camera.eye;
    const center = [eye[0] + camera.forward[0], eye[1] + camera.forward[1], eye[2] + camera.forward[2]];
    lookAt(this.view, eye, center, camera.up);
    multiply(this.vp, this.proj, this.view);
    const planes = planesFrom(this.vp);
    gl.clearColor(sky.horizon[0], sky.horizon[1], sky.horizon[2], 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    gl.disable(gl.CULL_FACE);
    gl.useProgram(this.skyProg);
    gl.uniform3fv(gl.getUniformLocation(this.skyProg, "uTop"), sky.top);
    gl.uniform3fv(gl.getUniformLocation(this.skyProg, "uHorizon"), sky.horizon);
    gl.uniform3fv(gl.getUniformLocation(this.skyProg, "uBottom"), sky.bottom);
    gl.uniform3fv(gl.getUniformLocation(this.skyProg, "uForward"), camera.forward);
    gl.uniform3fv(gl.getUniformLocation(this.skyProg, "uRight"), camera.right);
    gl.uniform3fv(gl.getUniformLocation(this.skyProg, "uUp"), camera.up);
    gl.uniform3fv(gl.getUniformLocation(this.skyProg, "uSun"), sky.sun);
    gl.uniform1f(gl.getUniformLocation(this.skyProg, "uDay"), day);
    gl.uniform1f(gl.getUniformLocation(this.skyProg, "uFovX"), Math.tan(fov * 0.5) * aspect);
    gl.uniform1f(gl.getUniformLocation(this.skyProg, "uFovY"), Math.tan(fov * 0.5));
    useAttribs(gl, this.skyBuf, [[0, 2, 0, 0]]);
    gl.drawArrays(gl.TRIANGLES, 0, 3);

    if (day < 0.65) {
      gl.enable(gl.BLEND);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE);
      gl.depthMask(false);
      gl.useProgram(this.starProg);
      const starVP = this.tmp;
      // Stars sit around the camera.
      const moved = new Float32Array(this.view);
      moved[12] = 0; moved[13] = 0; moved[14] = 0;
      multiply(starVP, this.proj, moved);
      gl.uniformMatrix4fv(gl.getUniformLocation(this.starProg, "uVP"), false, starVP);
      gl.uniform1f(gl.getUniformLocation(this.starProg, "uPoint"), Math.max(1.5, this.canvas.height / 420));
      gl.uniform1f(gl.getUniformLocation(this.starProg, "uAlpha"), (1 - day) * 0.9);
      useAttribs(gl, this.starBuf, [[0, 3, 0, 0]]);
      gl.drawArrays(gl.POINTS, 0, this.starCount);
      gl.depthMask(true);
      gl.disable(gl.BLEND);
    }

    gl.enable(gl.CULL_FACE);
    this.drawChunks(planes, "opaque", camera, skyFactor, sky.horizon, fogNear, fogFar, 0, 1);
    this.drawChunks(planes, "lava", camera, skyFactor, sky.horizon, fogNear, fogFar, time, 1, true);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    this.drawChunks(planes, "cutout", camera, skyFactor, sky.horizon, fogNear, fogFar, 1, 1);
    this.drawChunks(planes, "water", camera, skyFactor, sky.horizon, fogNear, fogFar, time, 0.72, true);

    gl.enable(gl.BLEND);
    gl.depthMask(false);
    gl.disable(gl.CULL_FACE);
    gl.useProgram(this.cloudProg);
    gl.uniformMatrix4fv(gl.getUniformLocation(this.cloudProg, "uVP"), false, this.vp);
    gl.uniform3f(gl.getUniformLocation(this.cloudProg, "uCam"), eye[0], eye[1], eye[2]);
    gl.uniform1f(gl.getUniformLocation(this.cloudProg, "uY"), 120);
    gl.uniform1f(gl.getUniformLocation(this.cloudProg, "uSize"), 220);
    gl.uniform1f(gl.getUniformLocation(this.cloudProg, "uTime"), time);
    gl.uniform1f(gl.getUniformLocation(this.cloudProg, "uDay"), day);
    gl.uniform3fv(gl.getUniformLocation(this.cloudProg, "uFog"), sky.horizon);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.cloudTex);
    gl.uniform1i(gl.getUniformLocation(this.cloudProg, "uTex"), 0);
    useAttribs(gl, this.cloudBuf, [[0, 2, 0, 0]]);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
    gl.depthMask(true);

    if (entities?.length || particles?.length) this.drawSolids(entities, particles, skyFactor);
    if (target) this.drawOutline(target);
    if (crack) this.drawCrack(crack, skyFactor);
    if (held) this.drawHeld(held, camera, skyFactor);
    gl.disable(gl.BLEND);
    gl.enable(gl.CULL_FACE);
    const err = gl.getError();
    if (err && !this.glNoted) {
      this.glNoted = true;
      const label = { 1280: "INVALID_ENUM", 1281: "INVALID_VALUE", 1282: "INVALID_OPERATION", 1285: "OUT_OF_MEMORY" }[err] || String(err);
      this.onError?.("描画エラー: " + label);
    }
  }

  drawChunks(planes, pass, camera, skyFactor, fog, fogNear, fogFar, cutoutOrTime, alpha, fluid) {
    const gl = this.gl;
    const prog = fluid ? this.fluidProg : this.chunkProg;
    gl.useProgram(prog);
    gl.uniformMatrix4fv(gl.getUniformLocation(prog, "uVP"), false, this.vp);
    gl.uniform3f(gl.getUniformLocation(prog, "uCam"), camera.eye[0], camera.eye[1], camera.eye[2]);
    gl.uniform1f(gl.getUniformLocation(prog, "uSky"), skyFactor);
    gl.uniform3fv(gl.getUniformLocation(prog, "uFog"), fog);
    gl.uniform1f(gl.getUniformLocation(prog, "uFogNear"), fogNear);
    gl.uniform1f(gl.getUniformLocation(prog, "uFogFar"), fogFar);
    gl.activeTexture(gl.TEXTURE0);
    if (fluid) {
      gl.bindTexture(gl.TEXTURE_2D, pass === "lava" ? this.lavaTex : this.waterTex);
      gl.uniform1i(gl.getUniformLocation(prog, "uTex"), 0);
      gl.uniform1f(gl.getUniformLocation(prog, "uTime"), cutoutOrTime);
      gl.uniform1f(gl.getUniformLocation(prog, "uAlpha"), pass === "lava" ? 1 : alpha);
      gl.uniform3f(gl.getUniformLocation(prog, "uTint"), 1, 1, 1);
    } else {
      gl.bindTexture(gl.TEXTURE_2D, this.atlas);
      gl.uniform1i(gl.getUniformLocation(prog, "uAtlas"), 0);
      gl.uniform1f(gl.getUniformLocation(prog, "uCols"), this.cols);
      gl.uniform1f(gl.getUniformLocation(prog, "uRows"), this.rows);
      gl.uniform1f(gl.getUniformLocation(prog, "uCutout"), cutoutOrTime);
      gl.uniform1f(gl.getUniformLocation(prog, "uAlpha"), alpha);
    }
    for (const [key, rec] of this.chunks) {
      const slot = rec[pass];
      if (!slot || !slot.count) continue;
      const [cx, cz] = key.split(",").map(Number);
      const min = [cx * SIZE, 0, cz * SIZE];
      const max = [min[0] + SIZE, HEIGHT, min[2] + SIZE];
      if (culled(planes, min, max)) continue;
      useAttribs(gl, slot.vbo, CHUNK_ATTRIBS);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, slot.ibo);
      gl.drawElements(gl.TRIANGLES, slot.count, gl.UNSIGNED_INT, 0);
    }
  }

  drawSolids(entities, particles, skyFactor) {
    const gl = this.gl;
    const verts = [];
    const pushBox = (x0, y0, z0, x1, y1, z1, color) => {
      const c = color.map((v) => v * (0.55 + 0.45 * skyFactor));
      const faces = [
        [x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1],
        [x1, y0, z0, x0, y0, z0, x0, y1, z0, x1, y1, z0],
        [x0, y1, z0, x1, y1, z0, x1, y1, z1, x0, y1, z1],
        [x0, y0, z1, x1, y0, z1, x1, y0, z0, x0, y0, z0],
        [x0, y0, z0, x0, y0, z1, x0, y1, z1, x0, y1, z0],
        [x1, y0, z1, x1, y0, z0, x1, y1, z0, x1, y1, z1],
      ];
      const shade = [0.78, 0.78, 1, 0.55, 0.66, 0.66];
      for (let f = 0; f < 6; f++) {
        const p = faces[f];
        const s = shade[f];
        const tri = [0, 1, 2, 0, 2, 3];
        for (const k of tri) {
          verts.push(p[k * 3], p[k * 3 + 1], p[k * 3 + 2], c[0] * s, c[1] * s, c[2] * s);
        }
      }
    };
    for (const ent of entities || []) {
      for (const part of ent.parts) {
        pushBox(ent.x + part.x, ent.y + part.y, ent.z + part.z, ent.x + part.x + part.w, ent.y + part.y + part.h, ent.z + part.z + part.d, part.color);
      }
    }
    for (const p of particles || []) {
      const s = p.size;
      pushBox(p.x, p.y, p.z, p.x + s, p.y + s, p.z + s, p.color);
    }
    if (!verts.length) return;
    gl.enable(gl.CULL_FACE);
    gl.disable(gl.BLEND);
    gl.useProgram(this.solidProg);
    gl.uniformMatrix4fv(gl.getUniformLocation(this.solidProg, "uVP"), false, this.vp);
    gl.uniform1f(gl.getUniformLocation(this.solidProg, "uAlpha"), 1);
    const buf = makeBuffer(gl, gl.ARRAY_BUFFER, new Float32Array(verts), gl.STREAM_DRAW);
    useAttribs(gl, buf, [[0, 3, 24, 0], [1, 3, 24, 12]]);
    gl.drawArrays(gl.TRIANGLES, 0, verts.length / 6);
    gl.deleteBuffer(buf);
  }

  drawOutline(target) {
    const gl = this.gl;
    gl.disable(gl.CULL_FACE);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    const grow = 0.004;
    const m = new Float32Array(16);
    m[0] = 1 + grow; m[5] = 1 + grow; m[10] = 1 + grow; m[15] = 1;
    m[12] = target.x - grow * 0.5;
    m[13] = target.y - grow * 0.5;
    m[14] = target.z - grow * 0.5;
    multiply(this.tmp, this.vp, m);
    gl.useProgram(this.solidProg);
    gl.uniformMatrix4fv(gl.getUniformLocation(this.solidProg, "uVP"), false, this.tmp);
    gl.uniform1f(gl.getUniformLocation(this.solidProg, "uAlpha"), 0.85);
    const line = [];
    const src = this.outline;
    for (let i = 0; i < src.length; i += 3) line.push(src[i], src[i + 1], src[i + 2], 0.05, 0.05, 0.05);
    const buf = makeBuffer(gl, gl.ARRAY_BUFFER, new Float32Array(line), gl.STREAM_DRAW);
    useAttribs(gl, buf, [[0, 3, 24, 0], [1, 3, 24, 12]]);
    gl.drawArrays(gl.LINES, 0, line.length / 6);
    gl.deleteBuffer(buf);
  }

  drawCrack(crack, skyFactor) {
    const gl = this.gl;
    const tile = TILE.CRACK + Math.max(0, Math.min(9, crack.stage | 0));
    const verts = [];
    const indices = [];
    const pad = 0.002;
    const x0 = crack.x - pad;
    const y0 = crack.y - pad;
    const z0 = crack.z - pad;
    const x1 = crack.x + 1 + pad;
    const y1 = crack.y + 1 + pad;
    const z1 = crack.z + 1 + pad;
    const light = [crack.sky / 15, crack.block / 15, 1];
    const quad = (a, b, c, d) => {
      const base = verts.length / 9;
      const pts = [a, b, c, d];
      const uvs = [[0, 0], [1, 0], [1, 1], [0, 1]];
      for (let i = 0; i < 4; i++) verts.push(pts[i][0], pts[i][1], pts[i][2], uvs[i][0], uvs[i][1], tile, light[0], light[1], light[2]);
      indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
    };
    quad([x0, y1, z1], [x1, y1, z1], [x1, y1, z0], [x0, y1, z0]);
    quad([x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1]);
    quad([x0, y0, z1], [x0, y0, z0], [x0, y1, z0], [x0, y1, z1]);
    quad([x1, y0, z0], [x1, y0, z1], [x1, y1, z1], [x1, y1, z0]);
    quad([x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0]);
    quad([x1, y0, z1], [x0, y0, z1], [x0, y1, z1], [x1, y1, z1]);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.useProgram(this.chunkProg);
    gl.uniformMatrix4fv(gl.getUniformLocation(this.chunkProg, "uVP"), false, this.vp);
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uSky"), skyFactor);
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uCutout"), 1);
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uAlpha"), 0.9);
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uFogNear"), 1000);
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uFogFar"), 1001);
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uCols"), this.cols);
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uRows"), this.rows);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.atlas);
    const vbo = makeBuffer(gl, gl.ARRAY_BUFFER, new Float32Array(verts), gl.STREAM_DRAW);
    const ibo = makeBuffer(gl, gl.ELEMENT_ARRAY_BUFFER, new Uint32Array(indices), gl.STREAM_DRAW);
    useAttribs(gl, vbo, CHUNK_ATTRIBS);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
    gl.drawElements(gl.TRIANGLES, indices.length, gl.UNSIGNED_INT, 0);
    gl.deleteBuffer(vbo);
    gl.deleteBuffer(ibo);
    void skyFactor;
    void blockOf;
    void tileOf;
  }

  drawHeld(held, camera, skyFactor) {
    const gl = this.gl;
    const swing = Math.sin(held.swing * Math.PI);
    const origin = [
      camera.eye[0] + camera.right[0] * 0.38 + camera.up[0] * (-0.36 - swing * 0.08) + camera.forward[0] * (0.62 + swing * 0.08),
      camera.eye[1] + camera.right[1] * 0.38 + camera.up[1] * (-0.36 - swing * 0.08) + camera.forward[1] * (0.62 + swing * 0.08),
      camera.eye[2] + camera.right[2] * 0.38 + camera.up[2] * (-0.36 - swing * 0.08) + camera.forward[2] * (0.62 + swing * 0.08),
    ];
    const tile = held.tile;
    const s = 0.18;
    const ax = camera.right;
    const ay = camera.up;
    const az = camera.forward.map((v) => -v);
    const verts = [];
    const corners = [
      [-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1],
      [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1],
    ].map(([x, y, z]) => [
      origin[0] + (ax[0] * x + ay[0] * y + az[0] * z) * s,
      origin[1] + (ax[1] * x + ay[1] * y + az[1] * z) * s,
      origin[2] + (ax[2] * x + ay[2] * y + az[2] * z) * s,
    ]);
    const faces = [[0, 1, 2, 3], [5, 4, 7, 6], [3, 2, 6, 7], [4, 5, 1, 0], [4, 0, 3, 7], [1, 5, 6, 2]];
    const indices = [];
    for (const f of faces) {
      const base = verts.length / 9;
      const uvs = [[0, 0], [1, 0], [1, 1], [0, 1]];
      for (let i = 0; i < 4; i++) {
        const p = corners[f[i]];
        verts.push(p[0], p[1], p[2], uvs[i][0], uvs[i][1], tile, 1, 1, 1);
      }
      indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
    }
    gl.clear(gl.DEPTH_BUFFER_BIT);
    gl.disable(gl.CULL_FACE);
    gl.enable(gl.BLEND);
    gl.useProgram(this.chunkProg);
    gl.uniformMatrix4fv(gl.getUniformLocation(this.chunkProg, "uVP"), false, this.vp);
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uSky"), Math.max(skyFactor, 0.65));
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uCutout"), 1);
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uAlpha"), 1);
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uFogNear"), 1000);
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uFogFar"), 1001);
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uCols"), this.cols);
    gl.uniform1f(gl.getUniformLocation(this.chunkProg, "uRows"), this.rows);
    const vbo = makeBuffer(gl, gl.ARRAY_BUFFER, new Float32Array(verts), gl.STREAM_DRAW);
    const ibo = makeBuffer(gl, gl.ELEMENT_ARRAY_BUFFER, new Uint32Array(indices), gl.STREAM_DRAW);
    useAttribs(gl, vbo, CHUNK_ATTRIBS);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
    gl.drawElements(gl.TRIANGLES, indices.length, gl.UNSIGNED_INT, 0);
    gl.deleteBuffer(vbo);
    gl.deleteBuffer(ibo);
  }
}

export function project(vp, x, y, z, width, height) {
  const cx = vp[0] * x + vp[4] * y + vp[8] * z + vp[12];
  const cy = vp[1] * x + vp[5] * y + vp[9] * z + vp[13];
  const cw = vp[3] * x + vp[7] * y + vp[11] * z + vp[15];
  if (cw <= 0.05) return null;
  return {
    x: (cx / cw * 0.5 + 0.5) * width,
    y: (-cy / cw * 0.5 + 0.5) * height,
  };
}
