import * as THREE from "three";

function gradient() {
  const canvas = document.createElement("canvas");
  canvas.width = 4;
  canvas.height = 1;
  const context = canvas.getContext("2d");
  ["#6a6a6a", "#9a9a9a", "#d4d4d4", "#ffffff"].forEach((color, index) => {
    context.fillStyle = color;
    context.fillRect(index, 0, 1, 1);
  });
  const texture = new THREE.CanvasTexture(canvas);
  texture.magFilter = THREE.NearestFilter;
  texture.minFilter = THREE.NearestFilter;
  return texture;
}

function toon(color, map) {
  return new THREE.MeshToonMaterial({ color, gradientMap: map });
}

export function createAvatar(canvas) {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.setClearColor(0x0c2344, 1);
  renderer.outputColorSpace = THREE.SRGBColorSpace;

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 30);
  camera.position.set(0, 0.22, 3.15);
  camera.lookAt(0, 0.05, 0);

  const map = gradient();
  const skin = toon(0xf6d2c0, map);
  const hairMat = toon(0x4a342b, map);
  const hairDeep = toon(0x3a291f, map);
  const blazer = toon(0x1d4b86, map);
  const blazerDark = toon(0x143566, map);
  const shirt = toon(0xf7f8f6, map);
  const lip = toon(0xe7a394, map);

  scene.add(new THREE.HemisphereLight(0xfff7f0, 0x16325c, 1.2));
  const key = new THREE.DirectionalLight(0xfff4ea, 1.45);
  key.position.set(1.2, 2.4, 2.6);
  scene.add(key);
  const fill = new THREE.DirectionalLight(0xb9cdee, 0.55);
  fill.position.set(-2.2, 0.8, 1.5);
  scene.add(fill);

  const glow = new THREE.Mesh(
    new THREE.CircleGeometry(1.15, 48),
    new THREE.MeshBasicMaterial({ color: 0x24548f, transparent: true, opacity: 0.55 }),
  );
  glow.position.set(0, 0.35, -1.1);
  scene.add(glow);

  const root = new THREE.Group();
  scene.add(root);
  const body = new THREE.Group();
  root.add(body);
  const head = new THREE.Group();
  head.position.y = 0.72;
  root.add(head);

  const hairBack = new THREE.Mesh(new THREE.SphereGeometry(0.58, 32, 24), hairDeep);
  hairBack.scale.set(1.05, 1.25, 0.82);
  hairBack.position.set(0, -0.08, -0.16);
  head.add(hairBack);

  const face = new THREE.Mesh(new THREE.SphereGeometry(0.46, 40, 32), skin);
  face.scale.set(0.9, 1.05, 0.82);
  face.position.z = 0.04;
  head.add(face);

  const crown = new THREE.Mesh(new THREE.SphereGeometry(0.42, 28, 18), hairMat);
  crown.scale.set(1.12, 0.48, 0.9);
  crown.position.set(0, 0.34, -0.02);
  head.add(crown);

  const bangs = new THREE.Mesh(new THREE.BoxGeometry(0.62, 0.1, 0.16), hairMat);
  bangs.position.set(0, 0.3, 0.3);
  bangs.rotation.x = 0.25;
  head.add(bangs);

  const lockGeo = new THREE.CapsuleGeometry(0.075, 0.85, 4, 10);
  const lockL = new THREE.Mesh(lockGeo, hairMat);
  lockL.position.set(-0.4, -0.22, 0.02);
  lockL.rotation.z = 0.08;
  head.add(lockL);
  const lockR = new THREE.Mesh(lockGeo, hairMat);
  lockR.position.set(0.4, -0.22, 0.02);
  lockR.rotation.z = -0.08;
  head.add(lockR);

  function makeEye(x) {
    const group = new THREE.Group();
    group.position.set(x, 0.05, 0.4);
    const white = new THREE.Mesh(
      new THREE.SphereGeometry(0.09, 20, 16),
      new THREE.MeshBasicMaterial({ color: 0xfffdfb }),
    );
    white.scale.set(1.2, 1.28, 0.4);
    group.add(white);
    const iris = new THREE.Mesh(
      new THREE.SphereGeometry(0.048, 16, 12),
      new THREE.MeshBasicMaterial({ color: 0x7a4b30 }),
    );
    iris.position.z = 0.025;
    group.add(iris);
    const pupil = new THREE.Mesh(
      new THREE.SphereGeometry(0.024, 12, 10),
      new THREE.MeshBasicMaterial({ color: 0x1c140f }),
    );
    pupil.position.z = 0.04;
    group.add(pupil);
    const light = new THREE.Mesh(
      new THREE.SphereGeometry(0.012, 8, 8),
      new THREE.MeshBasicMaterial({ color: 0xffffff }),
    );
    light.position.set(0.016, 0.018, 0.05);
    group.add(light);
    const lid = new THREE.Mesh(new THREE.SphereGeometry(0.1, 16, 12), skin);
    lid.scale.set(1.25, 0.08, 0.4);
    lid.position.set(0, 0.095, 0.01);
    group.add(lid);
    group.userData = { lid, iris, pupil };
    return group;
  }

  const eyeL = makeEye(-0.15);
  const eyeR = makeEye(0.15);
  head.add(eyeL, eyeR);

  const browGeo = new THREE.BoxGeometry(0.11, 0.018, 0.02);
  const browL = new THREE.Mesh(browGeo, hairDeep);
  browL.position.set(-0.15, 0.18, 0.4);
  browL.rotation.z = 0.12;
  head.add(browL);
  const browR = new THREE.Mesh(browGeo, hairDeep);
  browR.position.set(0.15, 0.18, 0.4);
  browR.rotation.z = -0.12;
  head.add(browR);

  const nose = new THREE.Mesh(new THREE.SphereGeometry(0.022, 10, 8), skin);
  nose.position.set(0, -0.04, 0.43);
  nose.scale.set(0.9, 0.7, 0.7);
  head.add(nose);

  const smile = new THREE.Mesh(new THREE.TorusGeometry(0.055, 0.012, 8, 16, Math.PI), lip);
  smile.position.set(0, -0.16, 0.39);
  smile.rotation.z = Math.PI;
  smile.rotation.x = 0.2;
  head.add(smile);
  const mouth = new THREE.Mesh(
    new THREE.SphereGeometry(0.04, 14, 10),
    new THREE.MeshBasicMaterial({ color: 0x9a4e56 }),
  );
  mouth.position.set(0, -0.175, 0.39);
  mouth.scale.set(1, 0.12, 0.3);
  head.add(mouth);

  const blushMat = new THREE.MeshBasicMaterial({ color: 0xf3a3a8, transparent: true, opacity: 0.35 });
  for (const x of [-0.22, 0.22]) {
    const blush = new THREE.Mesh(new THREE.CircleGeometry(0.045, 16), blushMat);
    blush.position.set(x, -0.05, 0.41);
    head.add(blush);
  }

  const neck = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.13, 0.18, 16), skin);
  neck.position.y = 0.38;
  body.add(neck);

  const jacket = new THREE.Mesh(new THREE.SphereGeometry(0.62, 28, 20), blazer);
  jacket.scale.set(1.2, 0.78, 0.62);
  jacket.position.y = -0.12;
  body.add(jacket);
  const jacketShade = new THREE.Mesh(new THREE.SphereGeometry(0.5, 20, 16), blazerDark);
  jacketShade.scale.set(1.35, 0.42, 0.4);
  jacketShade.position.set(0, -0.42, 0.02);
  body.add(jacketShade);

  const shirtFront = new THREE.Mesh(new THREE.BoxGeometry(0.22, 0.42, 0.08), shirt);
  shirtFront.position.set(0, -0.02, 0.28);
  body.add(shirtFront);
  const collarL = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.18, 0.03), shirt);
  collarL.position.set(-0.09, 0.2, 0.26);
  collarL.rotation.z = 0.55;
  body.add(collarL);
  const collarR = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.18, 0.03), shirt);
  collarR.position.set(0.09, 0.2, 0.26);
  collarR.rotation.z = -0.55;
  body.add(collarR);

  root.position.y = -0.55;

  let mode = "idle";
  let nod = 0;
  let blink = 0;
  let nextBlink = performance.now() + 1200;
  const clock = new THREE.Clock();
  let frame = 0;

  function resize() {
    const width = canvas.clientWidth || 640;
    const height = canvas.clientHeight || 720;
    if (canvas.width !== Math.floor(width * renderer.getPixelRatio())) {
      renderer.setSize(width, height, false);
      camera.aspect = width / Math.max(height, 1);
      camera.updateProjectionMatrix();
    }
  }

  function applyBlink(amount) {
    for (const eye of [eyeL, eyeR]) {
      eye.userData.lid.scale.y = 0.08 + amount * 1.15;
      eye.userData.lid.position.y = 0.095 - amount * 0.09;
    }
  }

  function loop() {
    frame = requestAnimationFrame(loop);
    const t = clock.getElapsedTime();
    const now = performance.now();
    resize();
    const breath = Math.sin(t * 1.35);
    body.position.y = breath * 0.015;
    body.scale.y = 1 + breath * 0.018;
    root.rotation.y = Math.sin(t * 0.4) * 0.08;
    root.rotation.z = Math.sin(t * 0.52) * 0.015;
    head.rotation.y = Math.sin(t * 0.46) * 0.06;
    head.rotation.z = Math.sin(t * 0.5) * 0.025;
    let pitch = Math.sin(t * 0.33) * 0.025;
    if (nod > 0) {
      nod = Math.max(0, nod - 0.04);
      pitch += Math.sin(nod * Math.PI) * 0.2;
    }
    if (mode === "listening") pitch += Math.max(0, Math.sin(t * 2.6)) * 0.07;
    if (mode === "thinking") pitch = -0.08;
    head.rotation.x = pitch;
    lockL.rotation.z = 0.08 + Math.sin(t * 0.8) * 0.025;
    lockR.rotation.z = -0.08 - Math.sin(t * 0.8) * 0.025;

    const lookX = Math.sin(t * 0.29) * 0.018;
    const lookY = Math.sin(t * 0.21) * 0.01 + (mode === "thinking" ? 0.012 : 0);
    for (const eye of [eyeL, eyeR]) {
      eye.userData.iris.position.x = lookX;
      eye.userData.iris.position.y = lookY;
      eye.userData.pupil.position.x = lookX * 0.7;
      eye.userData.pupil.position.y = lookY * 0.7;
    }

    if (blink === 0 && now > nextBlink) blink = 0.01;
    if (blink > 0) {
      blink += 0.14;
      const closed = blink < 1 ? blink : Math.max(0, 2 - blink);
      applyBlink(Math.min(1, closed));
      if (blink >= 2) {
        blink = 0;
        nextBlink = now + (Math.random() < 0.22 ? 240 : 2000 + Math.random() * 2400);
        applyBlink(0);
      }
    }

    const open = mode === "speaking" ? 0.25 + Math.abs(Math.sin(t * 11)) * 0.9 : 0.05;
    mouth.scale.y = 0.1 + open * 0.85;
    mouth.scale.x = 0.9 + open * 0.2;
    smile.position.y = -0.16 - open * 0.015;
    renderer.render(scene, camera);
    canvas.dataset.ready = "1";
  }

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
