import { hash3 } from "./constants.js";
import { AIR, GRASS, RAW_MEAT, SAND, blockOf, collides } from "./blocks.js";
import { inWater, moveBody } from "./physics.js";

function yawParts(parts, yaw, phase, hurt) {
  const c = Math.cos(yaw);
  const s = Math.sin(yaw);
  return parts.map((part) => {
    const rx = part.cx * c - part.cz * s;
    const rz = part.cx * s + part.cz * c;
    const w = Math.abs(part.w * c) + Math.abs(part.d * s);
    const d = Math.abs(part.w * s) + Math.abs(part.d * c);
    const bob = part.swing ? Math.sin(phase) * 0.08 : 0;
    const color = hurt > 0 ? [1, 0.85, 0.85] : part.color;
    return {
      x: rx - w * 0.5,
      y: part.cy + bob,
      z: rz - d * 0.5,
      w,
      h: part.h,
      d,
      color,
    };
  });
}

function boarParts() {
  return [
    { cx: 0, cy: 0.35, cz: 0, w: 0.7, h: 0.42, d: 0.4, color: [0.86, 0.55, 0.58], swing: false },
    { cx: 0.34, cy: 0.48, cz: 0, w: 0.28, h: 0.28, d: 0.28, color: [0.9, 0.6, 0.62] },
    { cx: -0.18, cy: 0, cz: 0.14, w: 0.12, h: 0.28, d: 0.12, color: [0.75, 0.45, 0.48], swing: true },
    { cx: -0.18, cy: 0, cz: -0.14, w: 0.12, h: 0.28, d: 0.12, color: [0.75, 0.45, 0.48], swing: true },
    { cx: 0.22, cy: 0, cz: 0.14, w: 0.12, h: 0.28, d: 0.12, color: [0.75, 0.45, 0.48], swing: true },
    { cx: 0.22, cy: 0, cz: -0.14, w: 0.12, h: 0.28, d: 0.12, color: [0.75, 0.45, 0.48], swing: true },
  ];
}

function walkerParts() {
  return [
    { cx: 0, cy: 0.72, cz: 0, w: 0.46, h: 0.62, d: 0.24, color: [0.36, 0.48, 0.34] },
    { cx: 0, cy: 1.32, cz: 0, w: 0.36, h: 0.36, d: 0.36, color: [0.45, 0.58, 0.4] },
    { cx: 0, cy: 0, cz: 0.1, w: 0.16, h: 0.7, d: 0.16, color: [0.28, 0.34, 0.28], swing: true },
    { cx: 0, cy: 0, cz: -0.1, w: 0.16, h: 0.7, d: 0.16, color: [0.28, 0.34, 0.28], swing: true },
    { cx: 0, cy: 0.72, cz: 0.32, w: 0.14, h: 0.55, d: 0.14, color: [0.32, 0.42, 0.3], swing: true },
    { cx: 0, cy: 0.72, cz: -0.32, w: 0.14, h: 0.55, d: 0.14, color: [0.32, 0.42, 0.3], swing: true },
  ];
}

export function playerAvatar(color) {
  return [
    { cx: 0, cy: 0.72, cz: 0, w: 0.5, h: 0.7, d: 0.28, color },
    { cx: 0, cy: 1.42, cz: 0, w: 0.4, h: 0.4, d: 0.4, color: [0.93, 0.78, 0.62] },
    { cx: 0, cy: 0, cz: 0.12, w: 0.18, h: 0.72, d: 0.18, color: [0.25, 0.28, 0.4], swing: true },
    { cx: 0, cy: 0, cz: -0.12, w: 0.18, h: 0.72, d: 0.18, color: [0.25, 0.28, 0.4], swing: true },
    { cx: 0, cy: 0.75, cz: 0.36, w: 0.16, h: 0.62, d: 0.16, color, swing: true },
    { cx: 0, cy: 0.75, cz: -0.36, w: 0.16, h: 0.62, d: 0.16, color, swing: true },
  ];
}

export function avatarColor(id) {
  const h = hash3(id.length, id.charCodeAt(0) || 1, id.charCodeAt(1) || 2, 7);
  const palette = [
    [0.35, 0.55, 0.86],
    [0.75, 0.32, 0.32],
    [0.32, 0.62, 0.4],
    [0.72, 0.55, 0.22],
    [0.55, 0.38, 0.72],
    [0.2, 0.62, 0.66],
  ];
  return palette[h % palette.length];
}

export class MobSystem {
  constructor() {
    this.list = [];
    this.timer = 2;
    this.phase = 0;
  }

  update(dt, world, player, host, hooks) {
    this.phase += dt * 6;
    if (!host) {
      for (const mob of this.list) {
        mob.x += (mob.tx - mob.x) * Math.min(1, dt * 8);
        mob.y += (mob.ty - mob.y) * Math.min(1, dt * 8);
        mob.z += (mob.tz - mob.z) * Math.min(1, dt * 8);
        mob.hurt = Math.max(0, mob.hurt - dt);
      }
      return;
    }
    this.timer -= dt;
    if (this.timer <= 0) {
      this.timer = 6;
      this.spawn(world, player);
    }
    for (const mob of this.list) {
      mob.hurt = Math.max(0, mob.hurt - dt);
      mob.attack = Math.max(0, (mob.attack || 0) - dt);
      const dx = player.x - mob.x;
      const dz = player.z - mob.z;
      const dist = Math.hypot(dx, dz);
      mob.ai -= dt;
      let speed = 0;
      if (mob.kind === "walker" && world.time % 24000 > 13000 && dist < 18) {
        mob.yaw = Math.atan2(dx, -dz);
        speed = 2.1;
        if (dist < 1.15 && mob.attack <= 0 && !player.dead) {
          mob.attack = 1;
          hooks.hurtPlayer(3, mob);
        }
      } else if (mob.flee > 0) {
        mob.flee -= dt;
        mob.yaw = Math.atan2(-dx, dz);
        speed = 2.4;
      } else if (mob.ai <= 0) {
        mob.ai = 2 + Math.random() * 3;
        mob.yaw += (Math.random() - 0.5) * 2.2;
        mob.walking = Math.random() > 0.35;
      }
      if (mob.kind === "boar" && mob.flee <= 0 && !mob.walking) speed = 0;
      if (mob.kind === "boar" && mob.walking && mob.flee <= 0) speed = 1.1;
      const vx = Math.sin(mob.yaw) * speed;
      const vz = -Math.cos(mob.yaw) * speed;
      mob.vy -= (inWater(world, mob) ? 6 : 28) * dt;
      if (mob.vy < -30) mob.vy = -30;
      moveBody(world, mob, vx * dt, mob.vy * dt, vz * dt, { step: 0.5, wasGround: mob.onGround });
      if (mob.y < -4 || dist > 72) mob.dead = true;
    }
    this.list = this.list.filter((mob) => !mob.dead && mob.health > 0);
  }

  spawn(world, player) {
    const night = (world.time % 24000) > 13000;
    const boars = this.list.filter((m) => m.kind === "boar").length;
    const walkers = this.list.filter((m) => m.kind === "walker").length;
    const kind = night && walkers < 5 ? "walker" : boars < 4 ? "boar" : null;
    if (!kind) return;
    for (let n = 0; n < 8; n++) {
      const ang = Math.random() * Math.PI * 2;
      const dist = 14 + Math.random() * 16;
      const x = Math.floor(player.x + Math.sin(ang) * dist);
      const z = Math.floor(player.z - Math.cos(ang) * dist);
      let y = 90;
      for (let yy = 100; yy > 2; yy--) {
        const id = world.getBlock(x, yy, z);
        if (id && id !== 255 && collides(id)) {
          y = yy + 1;
          break;
        }
      }
      const ground = world.getBlock(x, y - 1, z);
      if (ground !== GRASS && ground !== SAND && blockOf(ground)?.occlude !== true) continue;
      if (world.getBlock(x, y, z) !== AIR || world.getBlock(x, y + 1, z) !== AIR) continue;
      const mob = {
        id: "m" + Math.random().toString(36).slice(2, 7),
        kind,
        x: x + 0.5,
        y,
        z: z + 0.5,
        vx: 0, vy: 0, vz: 0,
        yaw: Math.random() * Math.PI * 2,
        w: 0.6, h: kind === "walker" ? 1.7 : 0.9, d: 0.6,
        health: kind === "walker" ? 20 : 10,
        ai: 1,
        walking: true,
        flee: 0,
        hurt: 0,
        attack: 0,
        onGround: false,
        tx: x, ty: y, tz: z,
      };
      this.list.push(mob);
      return;
    }
  }

  hit(id, damage, from) {
    const mob = this.list.find((m) => m.id === id);
    if (!mob) return null;
    mob.health -= damage;
    mob.hurt = 0.15;
    mob.flee = mob.kind === "boar" ? 3 : 0;
    const dx = mob.x - from.x;
    const dz = mob.z - from.z;
    const len = Math.hypot(dx, dz) || 1;
    mob.vx += (dx / len) * 4;
    mob.vz += (dz / len) * 4;
    mob.vy = 4;
    if (mob.health <= 0) {
      mob.dead = true;
      return mob.kind === "boar" ? { id: RAW_MEAT, count: 1 + (Math.random() < 0.4 ? 1 : 0), x: mob.x, y: mob.y + 0.3, z: mob.z } : null;
    }
    return null;
  }

  models() {
    return this.list.map((mob) => ({
      x: mob.x,
      y: mob.y,
      z: mob.z,
      parts: yawParts(mob.kind === "boar" ? boarParts() : walkerParts(), mob.yaw, this.phase, mob.hurt),
    }));
  }

  snapshot() {
    return this.list.map((m) => ({
      id: m.id, kind: m.kind, x: m.x, y: m.y, z: m.z, yaw: m.yaw, health: m.health,
    }));
  }

  applySnapshot(list) {
    const seen = new Set();
    for (const src of list || []) {
      seen.add(src.id);
      let mob = this.list.find((m) => m.id === src.id);
      if (!mob) {
        mob = { ...src, tx: src.x, ty: src.y, tz: src.z, hurt: 0, w: 0.6, h: 1, d: 0.6, vx: 0, vy: 0, vz: 0 };
        this.list.push(mob);
      }
      mob.tx = src.x;
      mob.ty = src.y;
      mob.tz = src.z;
      mob.yaw = src.yaw;
      mob.kind = src.kind;
      mob.health = src.health;
    }
    this.list = this.list.filter((m) => seen.has(m.id));
  }
}

export class DropSystem {
  constructor() {
    this.list = [];
  }

  spawn(x, y, z, id, count) {
    this.list.push({
      id, count,
      x, y, z,
      vx: (Math.random() - 0.5) * 2,
      vy: 3 + Math.random(),
      vz: (Math.random() - 0.5) * 2,
      age: 0,
      w: 0.2, h: 0.2, d: 0.2,
    });
  }

  update(dt, world, player, host, onPickup) {
    for (const item of this.list) {
      item.age += dt;
      if (!host) {
        const tx = item.tx ?? item.x;
        const ty = item.ty ?? item.y;
        const tz = item.tz ?? item.z;
        item.x += (tx - item.x) * Math.min(1, dt * 8);
        item.y += (ty - item.y) * Math.min(1, dt * 8);
        item.z += (tz - item.z) * Math.min(1, dt * 8);
        if (item.age > 0.45 && player) {
          const dx = player.x - item.x;
          const dy = player.y + 0.8 - item.y;
          const dz = player.z - item.z;
          if (dx * dx + dy * dy + dz * dz < 1.4) onPickup(item);
        }
        continue;
      }
      item.vy -= 18 * dt;
      moveBody(world, item, item.vx * dt, item.vy * dt, item.vz * dt);
      item.vx *= 0.9;
      item.vz *= 0.9;
      if (item.age > 0.45) {
        const dx = player.x - item.x;
        const dy = player.y + 0.8 - item.y;
        const dz = player.z - item.z;
        if (dx * dx + dy * dy + dz * dz < 1.4) {
          item.taken = true;
          onPickup(item);
        }
      }
      if (item.age > 300) item.taken = true;
    }
    this.list = this.list.filter((item) => !item.taken);
  }

  models(colorOf) {
    return this.list.map((item) => ({
      x: item.x,
      y: item.y + Math.sin(item.age * 3) * 0.05,
      z: item.z,
      parts: [{
        x: -0.12, y: 0, z: -0.12, w: 0.24, h: 0.24, d: 0.24,
        color: colorOf(item.id),
      }],
    }));
  }

  snapshot() {
    return this.list.map((d) => ({ id: d.id, count: d.count, x: d.x, y: d.y, z: d.z }));
  }

  applySnapshot(list) {
    this.list = (list || []).map((d, i) => {
      const prev = this.list[i];
      return {
        ...d,
        tx: d.x, ty: d.y, tz: d.z,
        x: prev ? prev.x : d.x,
        y: prev ? prev.y : d.y,
        z: prev ? prev.z : d.z,
        age: prev ? prev.age : 1,
        vx: 0, vy: 0, vz: 0, w: 0.2, h: 0.2, d: 0.2,
      };
    });
  }
}
