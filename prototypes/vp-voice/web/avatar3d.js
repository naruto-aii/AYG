import * as THREE from "three";
import { createMotion, stepMotion } from "./motion.js";

const DEFORM = `
uniform float uTime;
uniform float uSway;
uniform float uBreath;
uniform float uDepth;
uniform float uTurn;
uniform float uNod;
uniform float uHead;
uniform vec2 uGaze;
uniform vec2 uPivot;
`;

const DEFORM_BODY = `
float side = smoothstep(0.16, 0.46, abs(uv.x - 0.5));
float tip = smoothstep(0.62, 0.04, uv.y);
transformed.x += sin(uTime * 1.25 + uv.y * 6.0) * uSway * side * tip;
transformed.y += cos(uTime * 0.9 + uv.x * 3.0) * uSway * tip * 0.25;
float chest = smoothstep(0.55, 0.12, uv.y) * (1.0 - smoothstep(0.0, 0.42, abs(uv.x - 0.5)));
transformed.y += sin(uTime * 1.2) * uBreath * chest;
float head = smoothstep(0.30, 0.50, uv.y);
transformed.x += uTurn * 0.04 * head;
float ang = uNod * uHead * head * 0.28;
float cs = cos(ang);
float sn = sin(ang);
vec2 q = transformed.xy - uPivot;
q = vec2(cs * q.x - sn * q.y, sn * q.x + cs * q.y);
transformed.xy = mix(transformed.xy, q + uPivot, head) + uGaze;
`;

function deformMaterial(texture, uniforms) {
  const material = new THREE.MeshBasicMaterial({
    map: texture,
    transparent: true,
    depthWrite: false,
    toneMapped: false,
  });
  material.onBeforeCompile = (shader) => {
    Object.assign(shader.uniforms, uniforms);
    shader.vertexShader = shader.vertexShader
      .replace("#include <common>", `#include <common>\n${DEFORM}`)
      .replace("#include <begin_vertex>", `#include <begin_vertex>\n${DEFORM_BODY}`);
    material.userData.shader = shader;
  };
  return material;
}

function makeUniforms(layer) {
  return {
    uTime: { value: 0 },
    uSway: { value: layer.sway },
    uBreath: { value: layer.breath },
    uDepth: { value: layer.depth },
    uTurn: { value: 0 },
    uNod: { value: 0 },
    uHead: { value: layer.head },
    uGaze: { value: new THREE.Vector2() },
    uPivot: { value: new THREE.Vector2(0, -0.22) },
  };
}

function loadTexture(url) {
  return new Promise((resolve, reject) => {
    new THREE.TextureLoader().load(url, resolve, undefined, reject);
  });
}

function prepare(texture) {
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = 4;
  texture.needsUpdate = true;
  return texture;
}

export function createAvatar(canvas) {
  const renderer = new THREE.WebGLRenderer({
    canvas,
    antialias: true,
    alpha: false,
    premultipliedAlpha: false,
    preserveDrawingBuffer: true,
    powerPreference: "high-performance",
  });
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.NoToneMapping;
  renderer.setClearColor(0x0f1b33, 1);

  const scene = new THREE.Scene();
  const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
  camera.position.z = 4;
  const root = new THREE.Group();
  scene.add(root);

  const meshes = [];
  const motion = createMotion();
  const sample = { blink: 0, mouth: 0, nod: 0, turn: 0, gazeX: 0, gazeY: 0 };
  const motionInput = {
    time: 0,
    dt: 0,
    now: 0,
    mode: "idle",
    forcedBlink: "",
    forcedMouth: "",
    speech: null,
    manual: false,
    nodAt: -10,
  };
  let mode = "idle";
  let nodAt = -10;
  let simTime = 0;
  let lastNow = performance.now();
  let frame = 0;
  let speechLine = null;
  let appliedW = 0;
  let appliedH = 0;
  let appliedRatio = 0;

  function resize() {
    const width = Math.max(1, Math.floor(canvas.clientWidth || 640));
    const height = Math.max(1, Math.floor(canvas.clientHeight || 720));
    const ratio = Math.min(window.devicePixelRatio || 1, 1.5);
    if (width === appliedW && height === appliedH && ratio === appliedRatio) return;
    appliedW = width;
    appliedH = height;
    appliedRatio = ratio;
    renderer.setPixelRatio(ratio);
    renderer.setSize(width, height, false);
    const aspect = width / Math.max(height, 1);
    const viewHeight = aspect < 0.9 ? 1.62 : 1.9;
    const viewWidth = viewHeight * aspect;
    camera.left = -viewWidth / 2;
    camera.right = viewWidth / 2;
    camera.top = viewHeight * 0.56;
    camera.bottom = camera.top - viewHeight;
    camera.updateProjectionMatrix();
  }

  function advance(dt, now) {
    motionInput.time = simTime;
    motionInput.dt = dt;
    motionInput.now = now;
    motionInput.mode = canvas.dataset.pose || mode;
    motionInput.forcedBlink = canvas.dataset.blink ?? "";
    motionInput.forcedMouth = canvas.dataset.mouth ?? "";
    motionInput.speech = speechLine;
    motionInput.manual = canvas.dataset.manual === "1";
    motionInput.nodAt = nodAt;
    stepMotion(motion, motionInput, sample);
    for (const mesh of meshes) {
      const shader = mesh.material.userData.shader;
      if (!shader) continue;
      shader.uniforms.uTime.value = simTime;
      shader.uniforms.uNod.value = sample.nod;
      shader.uniforms.uTurn.value = sample.turn;
      shader.uniforms.uGaze.value.set(sample.gazeX, sample.gazeY);
      if (mesh.userData.lids && shader.uniforms.uBlink) shader.uniforms.uBlink.value = sample.blink;
      if (mesh.userData.mouth && shader.uniforms.uOpen) shader.uniforms.uOpen.value = sample.mouth;
    }
    return sample;
  }

  function renderAt(time) {
    if (time + 1e-4 < simTime) {
      const fresh = createMotion(motion.random);
      Object.assign(motion, fresh);
      nodAt = -10;
      simTime = 0;
    }
    const dt = time > simTime ? Math.min(0.05, time - simTime) : 1 / 60;
    simTime = time;
    if (appliedW === 0) resize();
    advance(dt, performance.now());
    renderer.render(scene, camera);
    return { blink: sample.blink, mouth: sample.mouth };
  }

  function loop(now) {
    frame = requestAnimationFrame(loop);
    if (canvas.dataset.manual === "1") return;
    const dt = Math.min(0.05, Math.max(0, (now - lastNow) / 1000));
    lastNow = now;
    simTime += dt;
    if (appliedW === 0) resize();
    advance(dt, now);
    renderer.render(scene, camera);
  }

  Promise.all([
    fetch("./avatar/layout.json").then((response) => response.json()),
    loadTexture("./avatar/source.jpg"),
    loadTexture("./avatar/eyelids.png"),
    loadTexture("./avatar/mouth-open.png"),
  ])
    .then(([layout, source, eyelids, mouth]) => {
      const [red, green, blue] = layout.background;
      renderer.setClearColor(new THREE.Color(red / 255, green / 255, blue / 255), 1);
      const layers = [
        { texture: prepare(source), sway: 0.009, breath: 0.006, depth: 0.2, head: 1, order: 1 },
        { texture: prepare(eyelids), sway: 0.009, breath: 0.006, depth: 0.2, head: 1, order: 2, lids: true },
        { texture: prepare(mouth), sway: 0.009, breath: 0.006, depth: 0.2, head: 1, order: 3, mouth: true },
      ];
      const mouthBox = new THREE.Vector4(
        layout.mouth.x / 1024,
        1 - (layout.mouth.y + layout.mouth.h) / 1024,
        (layout.mouth.x + layout.mouth.w) / 1024,
        1 - layout.mouth.y / 1024,
      );
      const boxes = (layout.eyes || []).slice(0, 2).map((eye) => new THREE.Vector4(
        (eye.x - 8) / 1024,
        1 - (eye.y + eye.h + 8) / 1024,
        (eye.x + eye.w + 8) / 1024,
        1 - (eye.y - 6) / 1024,
      ));
      for (const layer of layers) {
        const uniforms = makeUniforms(layer);
        const material = deformMaterial(layer.texture, uniforms);
        if (layer.lids) {
          const previous = material.onBeforeCompile;
          material.onBeforeCompile = (shader) => {
            previous(shader);
            shader.uniforms.uBlink = { value: 0 };
            shader.uniforms.uEyeA = { value: boxes[0] || new THREE.Vector4() };
            shader.uniforms.uEyeB = { value: boxes[1] || new THREE.Vector4() };
            shader.fragmentShader = shader.fragmentShader
              .replace(
                "#include <common>",
                `#include <common>
                uniform float uBlink;
                uniform vec4 uEyeA;
                uniform vec4 uEyeB;
                float lidMask(vec2 uv, vec4 eye) {
                  float insideX = step(eye.x, uv.x) * step(uv.x, eye.z);
                  float threshold = mix(eye.w, eye.y, clamp(uBlink, 0.0, 1.0));
                  return insideX * smoothstep(threshold - 0.02, threshold + 0.008, uv.y);
                }`,
              )
              .replace(
                "#include <alphatest_fragment>",
                `#include <alphatest_fragment>
                float lid = max(lidMask(vMapUv, uEyeA), lidMask(vMapUv, uEyeB));
                if (lid < 0.04) discard;
                diffuseColor.a *= lid;`,
              );
            material.userData.shader = shader;
          };
        }
        if (layer.mouth) {
          const previous = material.onBeforeCompile;
          material.onBeforeCompile = (shader) => {
            previous(shader);
            shader.uniforms.uOpen = { value: 0 };
            shader.uniforms.uMouth = { value: mouthBox };
            shader.fragmentShader = shader.fragmentShader
              .replace(
                "#include <common>",
                `#include <common>
                uniform float uOpen;
                uniform vec4 uMouth;`,
              )
              .replace(
                "#include <map_fragment>",
                `float open = clamp(uOpen, 0.0, 1.0);
                vec2 srcUv = vMapUv;
                float midY = (uMouth.y + uMouth.w) * 0.5;
                float midX = (uMouth.x + uMouth.z) * 0.5;
                srcUv.y = midY + (vMapUv.y - midY) / max(open, 0.045);
                srcUv.x = midX + (vMapUv.x - midX) / mix(0.62, 1.0, open);
                vec4 sampledDiffuseColor = texture2D(map, srcUv);
                sampledDiffuseColor.a *= smoothstep(0.02, 0.14, open);
                if (sampledDiffuseColor.a < 0.02) discard;
                diffuseColor *= sampledDiffuseColor;`,
              );
            material.userData.shader = shader;
          };
        }
        const mesh = new THREE.Mesh(new THREE.PlaneGeometry(2, 2, 32, 40), material);
        mesh.position.z = layer.order * 0.02;
        mesh.renderOrder = layer.order;
        mesh.userData.lids = Boolean(layer.lids);
        mesh.userData.mouth = Boolean(layer.mouth);
        root.add(mesh);
        meshes.push(mesh);
      }
      canvas.dataset.ready = "1";
    })
    .catch(() => {
      canvas.dataset.ready = "error";
    });

  resize();
  if (typeof ResizeObserver === "function") {
    const observer = new ResizeObserver(() => resize());
    observer.observe(canvas);
  }
  loop(performance.now());

  return {
    setMode(next) {
      mode = next || "idle";
    },
    setSpeech(info) {
      speechLine = info && info.text
        ? { text: String(info.text), at: performance.now(), rate: info.rate || 1.06 }
        : null;
    },
    nod() {
      nodAt = simTime;
    },
    renderAt,
    dispose() {
      cancelAnimationFrame(frame);
      renderer.dispose();
    },
  };
}
