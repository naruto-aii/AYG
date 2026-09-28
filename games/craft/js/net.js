import { joinRoom } from "../vendor/trystero-mqtt.js";

const RELAYS = [
  "wss://broker.hivemq.com:8884/mqtt",
  "wss://broker.emqx.io:8084/mqtt",
];

export function roomLink(code) {
  const url = new URL(window.location.href);
  url.search = "";
  url.hash = "";
  url.searchParams.set("room", code);
  return url.toString();
}

export function randomCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let out = "";
  for (let i = 0; i < 6; i++) out += alphabet[(Math.random() * alphabet.length) | 0];
  return out;
}

export class Net {
  constructor(game) {
    this.game = game;
    this.room = null;
    this.peers = new Map();
    this.host = false;
    this.code = "";
    this.modParts = [];
    this.modExpect = 0;
    this.connected = false;
    this.sendMsg = null;
  }

  connect(code, host) {
    this.host = host;
    this.code = code.toUpperCase();
    this.room = joinRoom({
      appId: "terrablock-ayg-v1",
      relayUrls: RELAYS,
      relayRedundancy: 2,
    }, "tb-" + this.code);
    const [send, get] = this.room.makeAction("m");
    this.sendMsg = send;
    get((data, peerId) => this.onMessage(peerId, data));
    this.room.onPeerJoin((id) => {
      if (!this.peers.has(id)) {
        this.peers.set(id, {
          id,
          name: "なかま",
          x: 0, y: 80, z: 0,
          tx: 0, ty: 80, tz: 0,
          yaw: 0, pitch: 0, sneak: false,
        });
      }
      this.connected = true;
      if (this.host) this.pushWelcome(id);
      this.game.onPeer(id, true);
    });
    this.room.onPeerLeave((id) => {
      this.peers.delete(id);
      this.game.onPeer(id, false);
    });
    this.sendMsg({ t: "hello", name: this.game.playerName, host });
  }

  leave() {
    try { this.room?.leave(); } catch { /* already gone */ }
    this.room = null;
    this.peers.clear();
    this.connected = false;
  }

  pushWelcome(peerId) {
    const mods = this.game.world.exportMods();
    const size = 600;
    const parts = Math.max(1, Math.ceil(mods.length / size) || 1);
    this.sendMsg({
      t: "welcome",
      seed: this.game.world.seed,
      time: this.game.world.time,
      rain: this.game.world.rain,
      parts,
      name: this.game.playerName,
    }, peerId);
    for (let i = 0; i < parts; i++) {
      this.sendMsg({ t: "mods", i, n: parts, data: mods.slice(i * size, (i + 1) * size) }, peerId);
    }
  }

  maybeStartGuest() {
    if (this.host || !this.welcome || !this.modParts?.length) return;
    if (this.modParts.some((part) => part == null)) return;
    const mods = this.modParts.flat();
    this.modParts = [];
    this.game.beginGuest(this.welcome.seed, this.welcome.time, mods);
  }

  send(data, peerId) {
    if (!this.sendMsg) return;
    this.sendMsg(data, peerId);
  }

  sendPos(player) {
    this.send({
      t: "pos",
      name: this.game.playerName,
      x: player.x, y: player.y, z: player.z,
      yaw: player.yaw, pitch: player.pitch,
      sneak: player.h < 1.7,
    });
  }

  onMessage(peerId, data) {
    if (!data || typeof data !== "object") return;
    const game = this.game;
    if (data.t === "hello") {
      const peer = this.peers.get(peerId) || { id: peerId, x: 0, y: 80, z: 0, tx: 0, ty: 80, tz: 0 };
      peer.name = data.name || "なかま";
      this.peers.set(peerId, peer);
      if (this.host) this.pushWelcome(peerId);
      return;
    }
    if (data.t === "welcome" && !this.host) {
      this.modExpect = data.parts || 1;
      if (!this.modParts || this.modParts.length !== this.modExpect) {
        const prev = this.modParts || [];
        this.modParts = new Array(this.modExpect);
        prev.forEach((part, i) => { if (part) this.modParts[i] = part; });
      }
      this.welcome = data;
      this.maybeStartGuest();
      return;
    }
    if (data.t === "mods" && !this.host) {
      const n = data.n || 1;
      if (!this.modParts || this.modParts.length !== n) this.modParts = new Array(n);
      this.modParts[data.i] = data.data || [];
      this.maybeStartGuest();
      return;
    }
    if (data.t === "pos") {
      const peer = this.peers.get(peerId);
      if (!peer) return;
      peer.name = data.name || peer.name;
      peer.tx = data.x; peer.ty = data.y; peer.tz = data.z;
      peer.yaw = data.yaw; peer.pitch = data.pitch; peer.sneak = data.sneak;
      if (!peer.seen) {
        peer.x = data.x; peer.y = data.y; peer.z = data.z;
        peer.seen = true;
      }
      return;
    }
    if (data.t === "block") {
      if (!game.world) return;
      game.world.setBlock(data.x, data.y, data.z, data.id, { silent: true });
      if (this.host && data.drop) {
        game.drops.spawn(data.x + 0.5, data.y + 0.35, data.z + 0.5, data.drop.id, data.drop.count);
      }
      if (this.host) {
        for (const id of this.peers.keys()) {
          if (id === peerId) continue;
          this.send({ t: "block", x: data.x, y: data.y, z: data.z, id: data.id }, id);
        }
      }
      return;
    }
    if (data.t === "time" && !this.host) {
      if (!game.world) return;
      const drift = data.time - game.world.time;
      if (Math.abs(drift) > 40) game.world.time = data.time;
      return;
    }
    if (data.t === "mobs" && !this.host) {
      game.mobs.applySnapshot(data.list);
      return;
    }
    if (data.t === "drops" && !this.host) {
      const now = performance.now();
      game.recentTakes = (game.recentTakes || []).filter((t) => t.until > now);
      const list = (data.list || []).filter((d) => !game.recentTakes.some((t) => t.id === d.id && Math.hypot(t.x - d.x, t.y - d.y, t.z - d.z) < 1.6));
      game.drops.applySnapshot(list);
      return;
    }
    if (data.t === "take" && this.host) {
      const item = game.drops.list.find((d) => d.id === data.id && Math.hypot(d.x - data.x, d.y - data.y, d.z - data.z) < 2.2);
      if (item) item.taken = true;
      return;
    }
    if (data.t === "hit" && this.host) {
      const drop = game.mobs.hit(data.id, data.dmg || 1, game.player);
      if (drop) game.drops.spawn(drop.x, drop.y, drop.z, drop.id, drop.count);
      return;
    }
    if (data.t === "chest") {
      if (!game.world) return;
      game.world.chests.set(data.key, data.slots);
      if (game.ui) game.ui.refresh();
      return;
    }
    if (data.t === "furnace") {
      if (!game.world) return;
      game.world.furnaces.set(data.key, data.furnace);
      if (game.ui) game.ui.refresh();
    }
  }
}
