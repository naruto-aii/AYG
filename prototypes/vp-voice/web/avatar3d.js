import * as THREE from "three";

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
transformed.x += uTurn * uDepth * 0.01;
float head = smoothstep(0.30, 0.50, uv.y);
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
  let mode = "idle";
  let nod = 0;
  let blink = 0;
  let nextBlink = performance.now() + 1100;
  let frame = 0;
  const clock = new THREE.Clock();

  function resize() {
    const width = canvas.clientWidth || 640;
    const height = canvas.clientHeight || 720;
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    if (canvas.width !== Math.floor(width * ratio)) renderer.setSize(width, height, false);
    const aspect = width / Math.max(height, 1);
    const viewHeight = aspect < 0.9 ? 1.62 : 1.9;
    const viewWidth = viewHeight * aspect;
    camera.left = -viewWidth / 2;
    camera.right = viewWidth / 2;
    camera.top = viewHeight * 0.56;
    camera.bottom = camera.top - viewHeight;
    camera.updateProjectionMatrix();
  }

  function loop() {
    frame = requestAnimationFrame(loop);
    const time = clock.getElapsedTime();
    const now = performance.now();
    resize();
    const forcedBlink = canvas.dataset.blink;
    const forcedMouth = canvas.dataset.mouth;
    const active = canvas.dataset.pose || mode;

    let blinkAmount = 0;
    if (forcedBlink != null && forcedBlink !== "") {
      blinkAmount = Math.min(1, Math.max(0, Number(forcedBlink)));
    } else {
      if (blink === 0 && now > nextBlink) blink = 0.01;
      if (blink > 0) {
        blink += 0.18;
        const phase = blink < 1 ? blink : Math.max(0, 2 - blink);
        blinkAmount = Math.min(1, phase);
        if (blink >= 2) {
          blink = 0;
          nextBlink = now + 1600 + Math.random() * 2800;
        }
      }
    }

    let mouth = 0;
    if (forcedMouth != null && forcedMouth !== "") mouth = Number(forcedMouth);
    else if (active === "speaking") {
      mouth = Math.max(0, 0.25 + Math.sin(time * 14) * 0.45 + Math.sin(time * 7.4) * 0.3);
    }

    let nodAmount = Math.sin(time * 0.5) * 0.06;
    if (nod > 0) {
      nod = Math.max(0, nod - 0.028);
      nodAmount += Math.sin(nod * Math.PI) * 0.85;
    }
    if (active === "listening") nodAmount += Math.max(0, Math.sin(time * 2.3)) * 0.55;
    if (active === "thinking") nodAmount -= 0.2;
    const turn = Math.sin(time * 0.38) * (active === "listening" ? 0.4 : 0.75);

    for (const mesh of meshes) {
      const shader = mesh.material.userData.shader;
      if (!shader) continue;
      shader.uniforms.uTime.value = time;
      shader.uniforms.uNod.value = nodAmount;
      shader.uniforms.uTurn.value = turn;
      if (mesh.userData.lids && shader.uniforms.uBlink) shader.uniforms.uBlink.value = blinkAmount;
      if (mesh.userData.mouth) mesh.material.opacity = mouth;
    }
    canvas.dataset.blinkAmount = blinkAmount.toFixed(2);
    canvas.dataset.mouthAmount = mouth.toFixed(2);
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
        { texture: prepare(source), sway: 0.014, breath: 0.01, depth: 0.2, head: 1, order: 1 },
        { texture: prepare(eyelids), sway: 0.014, breath: 0.01, depth: 0.85, head: 1, order: 2, lids: true },
        { texture: prepare(mouth), sway: 0.014, breath: 0.01, depth: 0.7, head: 1, order: 3, mouth: true },
      ];
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
                  return insideX * smoothstep(threshold - 0.01, threshold + 0.003, uv.y);
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
        const mesh = new THREE.Mesh(new THREE.PlaneGeometry(2, 2, 32, 40), material);
        mesh.position.z = layer.order * 0.02;
        mesh.renderOrder = layer.order;
        mesh.userData.lids = Boolean(layer.lids);
        mesh.userData.mouth = Boolean(layer.mouth);
        if (layer.mouth) material.opacity = 0;
        root.add(mesh);
        meshes.push(mesh);
      }
      canvas.dataset.ready = "1";
    })
    .catch(() => {
      canvas.dataset.ready = "error";
    });

  resize();
  loop();

  return {
    setMode(next) {
      mode = next || "idle";
    },
    nod() {
      nod = 1;
    },
    dispose() {
      cancelAnimationFrame(frame);
      renderer.dispose();
    },
  };
}
