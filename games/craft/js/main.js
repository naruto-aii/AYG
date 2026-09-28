import { smoothstep } from "./constants.js";
import { headInWater } from "./physics.js";
import { blockOf, collides, tileOf } from "./blocks.js";
import { createTextures } from "./textures.js";
import { Renderer, project } from "./renderer.js";
import { World } from "./world.js";
import { Player } from "./player.js";
import { DropSystem, MobSystem, avatarColor, playerAvatar } from "./entities.js";
import { AudioSys } from "./audio.js";
import { hasSave, loadSettings, loadWorld, saveSettings, saveWorld } from "./save.js";
import { Net, randomCode, roomLink } from "./net.js";
import { UI } from "./ui.js";

const SAVE = "latest";

function mix(a, b, t) {
  return [
    a[0] + (b[0] - a[0]) * t,
    a[1] + (b[1] - a[1]) * t,
    a[2] + (b[2] - a[2]) * t,
  ];
}

function skyFor(time) {
  const t = (time % 24000) / 24000;
  const sunY = Math.sin(t * Math.PI * 2);
  const day = smoothstep(-0.05, 0.32, sunY);
  const dusk = Math.exp(-(sunY * 3.1) ** 2) * (1 - day * 0.45);
  const top = mix([0.015, 0.02, 0.06], [0.34, 0.6, 0.95], day);
  const horizon = mix(mix([0.07, 0.07, 0.12], [0.7, 0.83, 0.96], day), [0.96, 0.46, 0.26], dusk);
  return {
    top,
    horizon,
    bottom: mix([0.05, 0.06, 0.08], [0.55, 0.68, 0.42], day),
    sun: [-Math.cos(t * Math.PI * 2), sunY, 0.18],
    day,
    skyFactor: 0.07 + 0.93 * day,
  };
}

class Game {
  constructor() {
    this.canvas = document.getElementById("view");
    this.textures = createTextures();
    this.renderer = new Renderer(this.canvas);
    this.audio = new AudioSys();
    this.settings = {
      renderDistance: matchMedia("(max-width: 860px), (pointer: coarse)").matches ? 4 : 6,
      sensitivity: 0.0022,
      touchSensitivity: 0.0065,
      fov: 74,
      volume: 0.55,
      music: 0.16,
      viewBob: true,
      ...loadSettings(),
    };
    this.ui = new UI(this);
    this.input = blankInput();
    this.playerName = "プレイヤー";
    this.running = false;
    this.paused = false;
    this.host = true;
    this.world = null;
    this.player = null;
    this.mobs = new MobSystem();
    this.drops = new DropSystem();
    this.net = null;
    this.particles = [];
    this.outgoingDrop = null;
    this.guestStarted = false;
    this.mode = "survival";
    this.netAcc = 0;
    this.saveAcc = 0;
    this.fps = 0;
    this.frames = 0;
    this.fpsAcc = 0;
    this.jumpQueued = 0;
    this.lastSpace = 0;
    this.debug = false;
    if (!this.renderer.ok) {
      document.getElementById("loading").classList.remove("hidden");
      document.getElementById("loading-text").textContent = "このブラウザは WebGL2 に対応していません。";
      return;
    }
    this.renderer.setTextures(this.textures);
    this.ui.setIcons(this.textures);
    this.bindInput();
    this.applySettings();
    this.ui.showTitle();
    const params = new URLSearchParams(location.search);
    if (params.get("autostart")) this.startSingle(params.get("autostart") === "creative" ? "creative" : "survival");
    this.last = performance.now();
    requestAnimationFrame((t) => this.frame(t));
  }

  applySettings() {
    saveSettings(this.settings);
    this.audio.setVolume(Number(this.settings.volume), Number(this.settings.music));
  }

  bindInput() {
    const setKey = (code, down) => {
      const map = {
        KeyW: "forward", KeyS: "back", KeyA: "left", KeyD: "right",
        Space: "jump", ShiftLeft: "sneak", ShiftRight: "sneak",
        ControlLeft: "sprint", ControlRight: "sprint",
      };
      if (map[code]) this.input[map[code]] = down;
    };
    window.addEventListener("keydown", (e) => {
      if (e.target.matches("input, textarea, select")) return;
      if (["Space", "ArrowUp", "ArrowDown"].includes(e.code)) e.preventDefault();
      setKey(e.code, true);
      if (!this.running || this.ui.blocking()) {
        if (e.code === "Escape") this.ui.showTitle();
        return;
      }
      if (e.code === "Escape") {
        if (!this.ui.el.panel.classList.contains("hidden")) this.ui.closePanel();
        else if (this.paused) this.resume();
        else this.ui.openPause();
      }
      if (e.code === "KeyE") this.ui.toggleInventory();
      if (e.code === "KeyQ") this.dropHeld(e.ctrlKey);
      if (e.code === "KeyF" && this.player?.creative) this.player.flying = !this.player.flying;
      if (e.code === "F3") {
        e.preventDefault();
        this.debug = !this.debug;
      }
      if (/^Digit[1-9]$/.test(e.code) && this.player) {
        this.player.inventory.selected = Number(e.code.slice(5)) - 1;
        this.ui.refresh();
        this.ui.flashItem(blockOf(this.player.inventory.heldId())?.name || "");
      }
      if (e.code === "Space" && this.player?.creative) {
        const now = performance.now();
        if (now - this.lastSpace < 280) this.player.flying = !this.player.flying;
        this.lastSpace = now;
      }
    });
    window.addEventListener("keyup", (e) => setKey(e.code, false));
    window.addEventListener("blur", () => { this.input = blankInput(); });
    this.canvas.addEventListener("click", () => {
      this.audio.unlock();
      if (this.running && !this.ui.blocking() && !document.body.classList.contains("mobile")) this.capture();
    });
    document.addEventListener("mousemove", (e) => {
      if (document.pointerLockElement !== this.canvas) return;
      this.input.lookX += e.movementX;
      this.input.lookY += e.movementY;
    });
    window.addEventListener("mousedown", (e) => {
      if (!this.running || this.ui.blocking()) return;
      if (e.button === 0) this.input.attack = true;
      if (e.button === 2) this.input.use = true;
    });
    window.addEventListener("mouseup", (e) => {
      if (e.button === 0) this.input.attack = false;
      if (e.button === 2) this.input.use = false;
    });
    window.addEventListener("contextmenu", (e) => e.preventDefault());
    window.addEventListener("wheel", (e) => {
      if (!this.player || this.ui.blocking()) return;
      const dir = Math.sign(e.deltaY);
      this.player.inventory.selected = (this.player.inventory.selected + dir + 9) % 9;
      this.ui.refresh();
    }, { passive: true });
    document.addEventListener("pointerlockchange", () => {
      if (document.pointerLockElement) return;
      if (this.ignoreUnlock) {
        this.ignoreUnlock = false;
        return;
      }
      if (this.running && !this.ui.blocking()) this.ui.openPause();
    });
    this.bindTouch();
    window.addEventListener("beforeunload", () => { this.save(false); });
  }

  bindTouch() {
    const stick = document.getElementById("stick");
    const knob = document.getElementById("knob");
    const look = document.getElementById("look");
    let sid = null;
    let origin = null;
    stick.addEventListener("pointerdown", (e) => {
      sid = e.pointerId;
      origin = { x: e.clientX, y: e.clientY };
      stick.setPointerCapture(e.pointerId);
    });
    stick.addEventListener("pointermove", (e) => {
      if (e.pointerId !== sid || !origin) return;
      const dx = Math.max(-42, Math.min(42, e.clientX - origin.x));
      const dy = Math.max(-42, Math.min(42, e.clientY - origin.y));
      knob.style.transform = `translate(${dx}px, ${dy}px)`;
      this.input.right = dx > 12;
      this.input.left = dx < -12;
      this.input.forward = dy < -12;
      this.input.back = dy > 12;
    });
    const endStick = (e) => {
      if (e.pointerId !== sid) return;
      sid = null;
      origin = null;
      knob.style.transform = "";
      this.input.right = this.input.left = this.input.forward = this.input.back = false;
    };
    stick.addEventListener("pointerup", endStick);
    stick.addEventListener("pointercancel", endStick);
    let lookId = null;
    let last = null;
    look.addEventListener("pointerdown", (e) => {
      lookId = e.pointerId;
      last = { x: e.clientX, y: e.clientY };
      this.audio.unlock();
    });
    look.addEventListener("pointermove", (e) => {
      if (e.pointerId !== lookId || !last || this.ui.blocking()) return;
      this.input.lookX += e.clientX - last.x;
      this.input.lookY += e.clientY - last.y;
      last = { x: e.clientX, y: e.clientY };
    });
    look.addEventListener("pointerup", () => { lookId = null; });
    const hold = (id, key) => {
      const el = document.getElementById(id);
      el.addEventListener("pointerdown", (e) => {
        e.preventDefault();
        this.input[key] = true;
        this.audio.unlock();
      });
      const up = () => { this.input[key] = false; };
      el.addEventListener("pointerup", up);
      el.addEventListener("pointerleave", up);
      el.addEventListener("pointercancel", up);
    };
    hold("btn-jump", "jump");
    hold("btn-break", "attack");
    hold("btn-place", "use");
    hold("btn-sneak", "sneak");
    document.getElementById("btn-fly").onclick = () => {
      if (this.player?.creative) this.player.flying = !this.player.flying;
    };
    document.getElementById("btn-pause").onclick = () => this.ui.openPause();
  }

  capture() {
    if (document.body.classList.contains("mobile")) return;
    this.canvas.requestPointerLock?.();
  }

  releasePointer() {
    this.ignoreUnlock = true;
    if (document.pointerLockElement) document.exitPointerLock();
    else this.ignoreUnlock = false;
  }

  async startSingle(mode) {
    this.audio.unlock();
    this.mode = mode;
    this.host = true;
    const seed = (Math.random() * 1e9) | 0;
    await this.startWorld({ seed, mode, host: true });
  }

  async continueGame() {
    this.audio.unlock();
    const data = await loadWorld(SAVE);
    if (!data) return this.ui.toast("セーブデータがありません");
    this.mode = data.player?.mode || "survival";
    this.host = true;
    await this.startWorld({
      seed: data.seed,
      time: data.time,
      mods: data.mods,
      player: data.player,
      chests: data.chests,
      furnaces: data.furnaces,
      mode: this.mode,
      host: true,
    });
  }

  async createRoom(mode) {
    this.audio.unlock();
    this.playerName = (document.getElementById("player-name").value || "ホスト").slice(0, 12);
    this.mode = mode;
    this.host = true;
    const code = randomCode();
    await this.startWorld({ seed: (Math.random() * 1e9) | 0, mode, host: true });
    this.net = new Net(this);
    try {
      this.net.connect(code, true);
      this.ui.setRoom(code, roomLink(code));
      this.ui.toast("部屋をつくりました。コードを共有してください");
    } catch (error) {
      this.ui.toast("通信を開始できませんでした");
      console.error(error);
    }
  }

  async joinRoom(code, mode) {
    this.audio.unlock();
    code = (code || "").trim().toUpperCase();
    if (code.length < 4) return this.ui.toast("部屋コードを入力してください");
    this.playerName = (document.getElementById("player-name").value || "ゲスト").slice(0, 12);
    this.mode = mode || "survival";
    this.host = false;
    this.guestStarted = false;
    this.ui.showLoading("ホストを待っています…");
    this.net = new Net(this);
    try {
      this.net.connect(code, false);
    } catch (error) {
      this.ui.toast("部屋に接続できませんでした");
      this.ui.showMp();
      console.error(error);
    }
    setTimeout(() => {
      if (!this.guestStarted && !this.running) {
        this.ui.toast("ホストが見つかりません。コードと通信環境を確認してください");
        this.ui.showMp();
      }
    }, 14000);
  }

  beginGuest(seed, time, mods) {
    if (this.guestStarted) return;
    this.guestStarted = true;
    this.startWorld({ seed, time, mods, mode: this.mode, host: false });
  }

  onPeer(id, joined) {
    this.ui.toast(joined ? "なかまが参加しました" : "なかまが退出しました");
  }

  async startWorld(opts) {
    this.ui.showLoading("地形を生成しています…");
    this.renderer.clearMeshes();
    if (this.world) this.world.dispose();
    this.world = new World(opts.seed >>> 0);
    this.world.attachWorker();
    this.world.time = opts.time ?? 1800;
    if (opts.mods) this.world.importMods(opts.mods);
    if (opts.chests) for (const [k, v] of opts.chests) this.world.chests.set(k, v);
    if (opts.furnaces) for (const [k, v] of opts.furnaces) this.world.furnaces.set(k, v);
    this.world.onUpload = (key, mesh) => this.renderer.upload(key, mesh);
    this.world.onDispose = (key) => this.renderer.drop(key);
    this.world.onBlock = (x, y, z, id) => {
      if (!this.net) return;
      const drop = id === 0 ? this.outgoingDrop : null;
      this.net.send({ t: "block", x, y, z, id, drop });
    };
    this.world.onSpill = (x, y, z, slots) => {
      for (const slot of slots) {
        if (slot) this.drops.spawn(x + 0.5, y + 0.5, z + 0.5, slot.id, slot.count);
      }
    };
    this.player = new Player(this.world, opts.mode);
    if (opts.player) this.player.importState(opts.player);
    this.mobs = new MobSystem();
    this.drops = new DropSystem();
    this.particles = [];
    this.host = opts.host !== false;
    this.running = false;
    const wait = () => {
      const radius = Math.min(2, this.settings.renderDistance);
      this.world.update(this.world.spawn.x, this.world.spawn.z, radius, 2);
      const key = `${Math.floor(this.world.spawn.x / 16)},${Math.floor(this.world.spawn.z / 16)}`;
      const chunk = this.world.chunks.get(key);
      if (chunk?.sky) {
        if (!opts.player) {
          const x = Math.floor(this.player.x);
          const z = Math.floor(this.player.z);
          for (let y = 120; y > 2; y--) {
            if (collides(this.world.getBlock(x, y, z))) {
              this.player.y = y + 1;
              break;
            }
          }
          this.player.spawn = { x: this.player.x, y: this.player.y, z: this.player.z };
        }
        this.running = true;
        this.paused = false;
        this.ui.showGame();
        this.ui.toast(this.player.creative ? "クリエイティブ：Fまたはスペース2回で飛行" : "木をこわして、板材をつくろう");
        this.capture();
        return;
      }
      requestAnimationFrame(wait);
    };
    wait();
  }

  breakBlock(x, y, z, drop) {
    const broken = this.world.getBlock(x, y, z);
    this.outgoingDrop = drop;
    this.world.setBlock(x, y, z, 0);
    this.outgoingDrop = null;
    this.audio.play("break");
    this.burst(x, y, z, broken && broken !== 255 ? broken : 3);
    if (drop && this.host) this.drops.spawn(x + 0.5, y + 0.35, z + 0.5, drop.id, drop.count);
  }

  placeBlock(x, y, z, id) {
    const prev = this.world.getBlock(x, y, z);
    if (prev === 255) return;
    if (collides(prev)) return;
    const ok = this.world.setBlock(x, y, z, id);
    if (!ok) return;
    this.player.inventory.consumeHeld(this.player.creative);
    this.player.swing = 1;
    this.audio.play("place");
    this.ui.refresh();
  }

  openBlock(x, y, z, kind) {
    this.ui.openPanel(kind === "craft" ? "craft" : kind, { x, y, z });
  }

  burst(x, y, z, id) {
    const tile = tileOf(id, "side");
    const sample = this.textures.sample(tile, 8, 8);
    for (let i = 0; i < 8; i++) {
      this.particles.push({
        x: x + Math.random(),
        y: y + Math.random(),
        z: z + Math.random(),
        vx: (Math.random() - 0.5) * 2.4,
        vy: 1 + Math.random() * 2,
        vz: (Math.random() - 0.5) * 2.4,
        life: 0.45 + Math.random() * 0.25,
        size: 0.08,
        color: [sample[0] / 255, sample[1] / 255, sample[2] / 255],
      });
    }
  }

  dropHeld(all) {
    const slot = this.player.inventory.slots[this.player.inventory.selected];
    if (!slot) return;
    const count = all ? slot.count : 1;
    this.drops.spawn(this.player.x, this.player.y + 1.2, this.player.z, slot.id, count);
    slot.count -= count;
    if (slot.count <= 0) this.player.inventory.slots[this.player.inventory.selected] = null;
    this.ui.refresh();
  }

  resume() {
    this.paused = false;
    this.ui.el.pause.classList.add("hidden");
    this.ui.el.settings.classList.add("hidden");
    if (this.running) this.capture();
  }

  respawn() {
    this.player.respawn();
    this.ui.el.death.classList.add("hidden");
    this.capture();
  }

  async save(toast = true) {
    if (!this.world || !this.player || (this.net && !this.host)) return;
    await saveWorld(SAVE, {
      seed: this.world.seed,
      time: this.world.time,
      mods: this.world.exportMods(),
      player: this.player.exportState(),
      chests: [...this.world.chests.entries()],
      furnaces: [...this.world.furnaces.entries()],
    });
    if (toast) this.ui.toast("セーブしました");
  }

  async saveAndExit() {
    await this.save(false);
    this.running = false;
    this.net?.leave();
    this.net = null;
    this.world?.dispose();
    this.ui.showTitle();
  }

  frame(now) {
    const dt = Math.min(0.05, (now - this.last) / 1000);
    this.last = now;
    this.frames++;
    this.fpsAcc += dt;
    if (this.fpsAcc > 0.5) {
      this.fps = Math.round(this.frames / this.fpsAcc);
      this.frames = 0;
      this.fpsAcc = 0;
    }
    if (this.running && this.world && this.player) this.tick(dt);
    this.draw(dt);
    requestAnimationFrame((t) => this.frame(t));
  }

  tick(dt) {
    const playing = !this.paused && !this.ui.blocking() && !this.player.dead;
    if (playing) {
      this.input.touch = document.body.classList.contains("mobile");
      this.player.update(dt, this.input, this);
      this.input.lookX = 0;
      this.input.lookY = 0;
    } else if (this.player.dead && this.ui.el.death.classList.contains("hidden")) {
      this.ui.showDeath();
    }
    if (this.host) {
      this.world.time += dt * 20;
      this.world.tickFurnaces(dt);
      this.mobs.update(dt, this.world, this.player, true, {
        hurtPlayer: (amount) => {
          this.player.hurt(amount);
          this.audio.play("hurt");
        },
      });
      this.drops.update(dt, this.world, this.player, true, (item) => {
        const left = this.player.inventory.add(item.id, item.count);
        if (left > 0) item.count = left;
        else item.taken = true;
        this.audio.play("pickup");
        this.ui.refresh();
      });
    } else {
      this.world.time += dt * 20;
      this.mobs.update(dt, this.world, this.player, false, {});
      this.drops.update(dt, this.world, this.player, false, (item) => {
        if (item.taken) return;
        const left = this.player.inventory.add(item.id, item.count);
        if (left > 0) {
          let undo = item.count - left;
          const slots = this.player.inventory.slots;
          for (let i = slots.length - 1; i >= 0 && undo > 0; i--) {
            const slot = slots[i];
            if (!slot || slot.id !== item.id) continue;
            const back = Math.min(slot.count, undo);
            slot.count -= back;
            undo -= back;
            if (slot.count <= 0) slots[i] = null;
          }
          return;
        }
        item.taken = true;
        this.recentTakes = this.recentTakes || [];
        this.recentTakes.push({ id: item.id, x: item.tx ?? item.x, y: item.ty ?? item.y, z: item.tz ?? item.z, until: performance.now() + 4000 });
        this.net?.send({ t: "take", id: item.id, x: item.tx ?? item.x, y: item.ty ?? item.y, z: item.tz ?? item.z });
        this.audio.play("pickup");
        this.ui.refresh();
      });
    }
    const radius = Number(this.settings.renderDistance) || 5;
    this.world.update(this.player.x, this.player.z, radius, document.body.classList.contains("mobile") ? 1 : 2);
    for (const p of this.particles) {
      p.life -= dt;
      p.vy -= 12 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.z += p.vz * dt;
    }
    this.particles = this.particles.filter((p) => p.life > 0);
    if (this.net) {
      this.netAcc += dt;
      if (this.netAcc > 0.08) {
        this.netAcc = 0;
        this.net.sendPos(this.player);
        for (const peer of this.net.peers.values()) {
          peer.x += (peer.tx - peer.x) * 0.5;
          peer.y += (peer.ty - peer.y) * 0.5;
          peer.z += (peer.tz - peer.z) * 0.5;
        }
      }
    }
    this.saveAcc += dt;
    this.stateAcc = (this.stateAcc || 0) + dt;
    if (this.net && this.host && this.stateAcc > 1) {
      this.stateAcc = 0;
      this.net.send({ t: "time", time: this.world.time });
      this.net.send({ t: "mobs", list: this.mobs.snapshot() });
      this.net.send({ t: "drops", list: this.drops.snapshot() });
    }
    if (this.host && this.saveAcc > 20) {
      this.saveAcc = 0;
      this.save(false);
    }
    const held = this.player.inventory.held();
    if (held && this.ui.el.itemName.dataset.id !== String(held.id) + this.player.inventory.selected) {
      this.ui.el.itemName.dataset.id = String(held.id) + this.player.inventory.selected;
    }
  }

  draw() {
    if (!this.renderer.ok) return;
    const sky = this.world ? skyFor(this.world.time) : skyFor(1800);
    let camera = {
      eye: [8, 78, 18],
      forward: [-0.4, -0.15, -0.9],
      right: [0.9, 0, -0.4],
      up: [0, 1, 0],
      fov: 70,
    };
    if (this.running && this.player && this.ui.el.title.classList.contains("hidden")) {
      camera = this.player.camera(this.settings, 0.016);
    }
    const submerged = !!(this.running && this.player && this.world && headInWater(this.world, this.player));
    const fog = submerged ? [0.05, 0.16, 0.38] : sky.horizon;
    const dist = (Number(this.settings.renderDistance) || 5) * 16;
    const entities = [];
    if (this.running) {
      entities.push(...this.mobs.models());
      entities.push(...this.drops.models((id) => {
        const sample = this.textures.sample(tileOf(id, "side"), 8, 8);
        return [sample[0] / 255, sample[1] / 255, sample[2] / 255];
      }));
      if (this.net) {
        for (const peer of this.net.peers.values()) {
          entities.push({
            x: peer.x,
            y: peer.y,
            z: peer.z,
            parts: playerAvatar(avatarColor(peer.id)).map((part) => {
              const yaw = peer.yaw || 0;
              const c = Math.cos(yaw);
              const s = Math.sin(yaw);
              const rx = part.cx * c - part.cz * s;
              const rz = part.cx * s + part.cz * c;
              return { x: rx - part.w / 2, y: part.cy, z: rz - part.d / 2, w: part.w, h: part.h, d: part.d, color: part.color };
            }),
          });
        }
      }
    }
    const heldItem = this.player?.inventory.held();
    const target = this.player?.target;
    this.renderer.render({
      camera,
      sky,
      fogNear: submerged ? 1 : dist * 0.55,
      fogFar: submerged ? 18 : dist * 0.95,
      skyFactor: sky.skyFactor,
      time: (this.world?.time || 0) / 20,
      day: sky.day,
      dpr: Math.min(window.devicePixelRatio || 1, document.body.classList.contains("mobile") ? 1.25 : 1.6),
      target: target ? { x: target.x, y: target.y, z: target.z } : null,
      crack: this.player && this.player.breakProgress > 0 && target ? {
        x: target.x, y: target.y, z: target.z,
        stage: Math.min(9, Math.floor(this.player.breakProgress * 10)),
        sky: 15, block: 0,
      } : null,
      entities,
      particles: this.particles,
      held: heldItem ? { tile: tileOf(heldItem.id, "side"), swing: this.player.swing } : null,
    });
    if (this.running && this.net && this.renderer.vp) {
      const tags = [];
      for (const peer of this.net.peers.values()) {
        const p = project(this.renderer.vp, peer.x, peer.y + 2.1, peer.z, this.canvas.clientWidth, this.canvas.clientHeight);
        if (p) tags.push({ x: p.x, y: p.y, name: peer.name || "なかま" });
      }
      this.ui.updateNametags(tags);
    } else this.ui.updateNametags([]);
    if (this.debug && this.player) {
      this.ui.setDebug(`FPS ${this.fps}  X ${this.player.x.toFixed(1)} Y ${this.player.y.toFixed(1)} Z ${this.player.z.toFixed(1)}  チャンク ${this.world.chunks.size}`);
    } else this.ui.setDebug("");
  }
}

function blankInput() {
  return {
    forward: false, back: false, left: false, right: false,
    jump: false, sneak: false, sprint: false,
    attack: false, use: false, lookX: 0, lookY: 0, touch: false,
  };
}

window.addEventListener("DOMContentLoaded", () => {
  const game = new Game();
  window.terrablock = game;
  hasSave(SAVE).then((ok) => {
    document.getElementById("continue-btn").classList.toggle("hidden", !ok);
  });
});
