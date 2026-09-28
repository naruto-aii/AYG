import { clamp } from "./constants.js";
import {
  BEDROCK, CACTUS, LAVA, WATER, blockOf, breakDuration, collides, dropFor, isFood,
} from "./blocks.js";
import { headInWater, inLava, inWater, moveBody, rayAabb, raycast } from "./physics.js";
import { Inventory } from "./inventory.js";

export class Player {
  constructor(world, mode) {
    this.world = world;
    this.mode = mode;
    this.creative = mode === "creative";
    this.x = world.spawn.x + 0.5;
    this.y = world.spawn.y;
    this.z = world.spawn.z + 0.5;
    this.vx = 0;
    this.vy = 0;
    this.vz = 0;
    this.yaw = 0;
    this.pitch = 0;
    this.w = 0.6;
    this.h = 1.8;
    this.d = 0.6;
    this.eye = 1.62;
    this.onGround = false;
    this.wasGround = false;
    this.health = 20;
    this.hunger = 20;
    this.air = 300;
    this.fall = 0;
    this.flying = false;
    this.inventory = new Inventory();
    this.breakProgress = 0;
    this.breakKey = "";
    this.swing = 0;
    this.eat = 0;
    this.attackCd = 0;
    this.hurtFlash = 0;
    this.dead = false;
    this.bob = 0;
    this.fovBlend = 72;
    this.hungerTick = 0;
    this.regen = 0;
    this.starve = 0;
    this.spawn = { x: this.x, y: this.y, z: this.z };
    this.justJumped = false;
    this.useLatch = false;
  }

  lookVector() {
    const cp = Math.cos(this.pitch);
    return [
      Math.sin(this.yaw) * cp,
      Math.sin(this.pitch),
      -Math.cos(this.yaw) * cp,
    ];
  }

  camera(settings, dt) {
    const moving = Math.hypot(this.vx, this.vz) > 0.4 && this.onGround && !this.flying;
    if (moving && settings.viewBob !== false) this.bob += dt * 9;
    else this.bob *= 0.85;
    const bobY = settings.viewBob === false ? 0 : Math.sin(this.bob) * 0.045;
    const roll = settings.viewBob === false ? 0 : Math.cos(this.bob) * 0.012;
    const [fx, fy, fz] = this.lookVector();
    const right = [Math.cos(this.yaw), 0, Math.sin(this.yaw)];
    const up = [
      right[1] * fz - right[2] * fy,
      right[2] * fx - right[0] * fz,
      right[0] * fy - right[1] * fx,
    ];
    const ulen = Math.hypot(up[0], up[1], up[2]) || 1;
    up[0] /= ulen; up[1] /= ulen; up[2] /= ulen;
    const target = this.flying ? settings.fov : settings.fov + (Math.hypot(this.vx, this.vz) > 6 ? 8 : 0);
    this.fovBlend += (target - this.fovBlend) * Math.min(1, dt * 6);
    return {
      eye: [this.x, this.y + (this.h < 1.7 ? 1.32 : this.eye) + bobY, this.z],
      forward: [fx, fy, fz],
      right,
      up: [
        up[0] * Math.cos(roll) + right[0] * Math.sin(roll),
        up[1] * Math.cos(roll) + right[1] * Math.sin(roll),
        up[2] * Math.cos(roll) + right[2] * Math.sin(roll),
      ],
      fov: this.fovBlend,
    };
  }

  hurt(amount) {
    if (this.creative || this.dead) return;
    this.health = Math.max(0, this.health - amount);
    this.hurtFlash = 0.35;
    if (this.health <= 0) this.dead = true;
  }

  update(dt, input, game) {
    if (this.dead) return;
    this.hurtFlash = Math.max(0, this.hurtFlash - dt);
    this.attackCd = Math.max(0, this.attackCd - dt);
    if (this.swing > 0) this.swing = Math.max(0, this.swing - dt * 3);
    const sens = input.touch ? game.settings.touchSensitivity : game.settings.sensitivity;
    this.yaw += input.lookX * sens / 0.0022;
    this.pitch = clamp(this.pitch - input.lookY * sens / 0.0022, -1.45, 1.45);

    const sneak = input.sneak && !this.flying;
    this.h = sneak ? 1.5 : 1.8;
    let speed = sneak ? 1.35 : input.sprint && this.hunger > 6 ? 5.6 : 4.3;
    if (this.creative && this.flying) speed = input.sprint ? 16 : 10;
    const water = inWater(this.world, this);
    const lava = inLava(this.world, this);
    if (water) speed *= 0.45;

    let mx = 0;
    let mz = 0;
    if (input.forward) { mx += Math.sin(this.yaw); mz -= Math.cos(this.yaw); }
    if (input.back) { mx -= Math.sin(this.yaw); mz += Math.cos(this.yaw); }
    if (input.right) { mx += Math.cos(this.yaw); mz += Math.sin(this.yaw); }
    if (input.left) { mx -= Math.cos(this.yaw); mz -= Math.sin(this.yaw); }
    const mag = Math.hypot(mx, mz) || 1;
    mx = (mx / mag) * speed;
    mz = (mz / mag) * speed;
    if (!input.forward && !input.back && !input.left && !input.right) { mx = 0; mz = 0; }

    if (this.creative && this.flying) {
      this.vy = 0;
      if (input.jump) this.vy += speed;
      if (input.sneak) this.vy -= speed;
      this.vx = mx;
      this.vz = mz;
    } else if (water) {
      this.vy += (input.jump ? 14 : -8) * dt;
      this.vy *= 0.86;
      this.vx += (mx - this.vx) * Math.min(1, dt * 6);
      this.vz += (mz - this.vz) * Math.min(1, dt * 6);
      this.fall = 0;
    } else {
      this.vy -= 28 * dt;
      if (this.vy < -40) this.vy = -40;
      if (input.jump && this.onGround) {
        this.vy = 8.5;
        this.onGround = false;
        if (!this.creative) this.hungerTick += 0.15;
      }
      const accel = this.onGround ? 14 : 2.2;
      this.vx += (mx - this.vx) * Math.min(1, dt * accel);
      this.vz += (mz - this.vz) * Math.min(1, dt * accel);
      if (this.onGround) {
        this.vx *= Math.pow(0.2, dt);
        this.vz *= Math.pow(0.2, dt);
      }
    }

    if (!this.onGround && this.vy < 0 && !water && !this.flying) this.fall -= this.vy * dt;
    const beforeGround = this.onGround;
    moveBody(this.world, this, this.vx * dt, this.vy * dt, this.vz * dt, {
      step: sneak || this.flying ? 0 : 0.55,
      sneak,
      wasGround: beforeGround,
    });
    if (this.onGround && this.fall > 3.2 && !this.creative) {
      this.hurt(this.fall - 3);
      game.audio.play("hurt");
    }
    if (this.onGround) this.fall = 0;

    if (lava) {
      this.hurt(4 * dt * 2);
      this.vy = Math.min(this.vy, 2);
    }
    if (headInWater(this.world, this) && !this.creative) {
      this.air -= dt * 20;
      if (this.air <= 0) {
        this.air = 0;
        this.hurt(dt * 2);
      }
    } else this.air = Math.min(300, this.air + dt * 40);

    const cactus = this.world.getBlock(Math.floor(this.x), Math.floor(this.y + 0.2), Math.floor(this.z));
    if (cactus === CACTUS) this.hurt(dt);

    if (!this.creative) {
      const moving = Math.hypot(this.vx, this.vz) > 0.8;
      this.hungerTick += dt * (input.sprint && moving ? 0.08 : moving ? 0.025 : 0.008);
      if (this.hungerTick > 4) {
        this.hungerTick = 0;
        this.hunger = Math.max(0, this.hunger - 0.5);
      }
      if (this.hunger <= 0) {
        this.starve += dt;
        if (this.starve > 4) {
          this.starve = 0;
          this.hurt(1);
        }
      }
      if (this.hunger >= 18 && this.health < 20 && this.health > 0) {
        this.regen += dt;
        if (this.regen > 4) {
          this.regen = 0;
          this.health = Math.min(20, this.health + 1);
        }
      }
    }

    this.interact(dt, input, game);
    game.audio.foot(dt, Math.hypot(this.vx, this.vz) > 1.2, this.onGround && !this.flying);
  }

  interact(dt, input, game) {
    const eyeY = this.y + (this.h < 1.7 ? 1.27 : this.eye);
    const dir = this.lookVector();
    const reach = this.creative ? 6 : 4.5;
    const hit = raycast(this.world, this.x, eyeY, this.z, dir[0], dir[1], dir[2], reach);
    let mobHit = null;
    let mobDist = reach;
    for (const mob of game.mobs.list) {
      const t = rayAabb(this.x, eyeY, this.z, dir[0], dir[1], dir[2], {
        minX: mob.x - 0.35, maxX: mob.x + 0.35,
        minY: mob.y, maxY: mob.y + mob.h,
        minZ: mob.z - 0.35, maxZ: mob.z + 0.35,
      }, reach);
      if (t != null && t < mobDist && (!hit || t < hit.dist)) {
        mobDist = t;
        mobHit = mob;
      }
    }
    this.target = mobHit ? null : hit;

    const held = this.inventory.held();
    if (input.attack && mobHit && this.attackCd <= 0) {
      this.attackCd = 0.45;
      this.swing = 1;
      const dmg = blockOf(held?.id)?.attack || 1;
      if (game.net && !game.host) game.net.send({ t: "hit", id: mobHit.id, dmg });
      else {
        const drop = game.mobs.hit(mobHit.id, dmg, this);
        if (drop) game.drops.spawn(drop.x, drop.y, drop.z, drop.id, drop.count);
      }
      game.audio.play("hit");
    }

    if (input.attack && hit && !mobHit) {
      const key = hit.x + "," + hit.y + "," + hit.z;
      const id = this.world.getBlock(hit.x, hit.y, hit.z);
      if (id === BEDROCK) {
        this.breakProgress = 0;
      } else if (this.breakKey !== key) {
        this.breakKey = key;
        this.breakProgress = 0;
      } else {
        const dur = breakDuration(id, held?.id || 0, this.creative);
        this.breakProgress += dt / dur;
        this.swing = 1;
        if (this.breakProgress >= 1) {
          this.breakProgress = 0;
          this.breakKey = "";
          const roll = hashRoll(hit.x, hit.y, hit.z, game.world.time | 0);
          const drop = this.creative ? null : dropFor(id, held?.id || 0, roll);
          game.breakBlock(hit.x, hit.y, hit.z, drop);
        }
      }
    } else {
      this.breakProgress = 0;
      this.breakKey = "";
    }

    if (input.use && !this.useLatch) {
      this.useLatch = true;
      const food = held && isFood(held.id);
      if (food && this.hunger < 20 && !this.creative) {
        this.eat = 0.01;
      } else if (hit && blockOf(hit.id)?.interactive && !input.sneak) {
        game.openBlock(hit.x, hit.y, hit.z, blockOf(hit.id).interactive);
      } else if (held && blockOf(held.id)?.placeable && hit) {
        const px = hit.px;
        const py = hit.py;
        const pz = hit.pz;
        if (!this.occupies(px, py, pz) && this.world.getBlock(px, py, pz) !== 255) {
          const current = this.world.getBlock(px, py, pz);
          if (!collides(current) || current === WATER || current === LAVA) {
            game.placeBlock(px, py, pz, held.id);
          }
        }
      }
    }
    if (!input.use) {
      this.useLatch = false;
      this.eat = 0;
    }
    if (this.eat > 0) {
      this.eat += dt;
      if (this.eat > 1.6 && held && isFood(held.id)) {
        this.hunger = Math.min(20, this.hunger + blockOf(held.id).food.hunger);
        this.inventory.consumeHeld(false);
        this.eat = 0;
        this.useLatch = true;
        game.audio.play("eat");
      }
    }
  }

  occupies(x, y, z) {
    const minX = this.x - this.w * 0.5;
    const maxX = this.x + this.w * 0.5;
    const minZ = this.z - this.d * 0.5;
    const maxZ = this.z + this.d * 0.5;
    return x + 1 > minX && x < maxX && y + 1 > this.y && y < this.y + this.h && z + 1 > minZ && z < maxZ;
  }

  respawn() {
    this.dead = false;
    this.health = 20;
    this.hunger = 20;
    this.air = 300;
    this.fall = 0;
    this.vx = this.vy = this.vz = 0;
    this.x = this.spawn.x;
    this.y = this.spawn.y;
    this.z = this.spawn.z;
  }

  exportState() {
    return {
      x: this.x, y: this.y, z: this.z, yaw: this.yaw, pitch: this.pitch,
      health: this.health, hunger: this.hunger, mode: this.mode,
      slots: this.inventory.slots,
      selected: this.inventory.selected,
    };
  }

  importState(data) {
    if (!data) return;
    this.x = data.x;
    this.y = data.y;
    this.z = data.z;
    this.yaw = data.yaw || 0;
    this.pitch = data.pitch || 0;
    this.health = data.health ?? 20;
    this.hunger = data.hunger ?? 20;
    this.mode = data.mode || this.mode;
    this.creative = this.mode === "creative";
    if (data.slots) this.inventory.slots = data.slots.map((s) => s ? { ...s } : null);
    this.inventory.selected = data.selected || 0;
    this.spawn = { x: this.x, y: this.y, z: this.z };
  }
}

function hashRoll(x, y, z, salt) {
  let h = (x * 374761393 ^ y * 668265263 ^ z * 1274126177 ^ salt) >>> 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}
