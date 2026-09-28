import { blockOf, CREATIVE_IDS, tileOf } from "./blocks.js";
import { clickStack } from "./inventory.js";
import { matchCraft } from "./crafting.js";

export class UI {
  constructor(game) {
    this.game = game;
    this.tex = null;
    this.panel = null;
    this.cursor = null;
    this.kind = null;
    this.pos = null;
    this.toastTimer = 0;
    this.itemTimer = 0;
    this.mobile = matchMedia("(pointer: coarse), (max-width: 860px)").matches;
    if (this.mobile) document.body.classList.add("mobile");
    this.cache();
    this.bind();
    window.addEventListener("resize", () => {
      const next = matchMedia("(pointer: coarse), (max-width: 860px)").matches;
      document.body.classList.toggle("mobile", next);
      this.mobile = next;
    });
  }

  cache() {
    this.el = {
      title: document.getElementById("title"),
      loading: document.getElementById("loading"),
      loadingText: document.getElementById("loading-text"),
      hud: document.getElementById("hud"),
      hearts: document.getElementById("hearts"),
      food: document.getElementById("food"),
      air: document.getElementById("air"),
      hotbar: document.getElementById("hotbar"),
      itemName: document.getElementById("item-name"),
      toast: document.getElementById("toast"),
      panel: document.getElementById("panel"),
      pause: document.getElementById("pause"),
      settings: document.getElementById("settings"),
      death: document.getElementById("death"),
      mp: document.getElementById("mp"),
      roomCode: document.getElementById("room-code"),
      roomLink: document.getElementById("room-link"),
      joinCode: document.getElementById("join-code"),
      nameInput: document.getElementById("player-name"),
      nametags: document.getElementById("nametags"),
      crosshair: document.getElementById("crosshair"),
      debug: document.getElementById("debug"),
      continueBtn: document.getElementById("continue-btn"),
      touch: document.getElementById("touch"),
    };
    this.el.hearts.innerHTML = Array.from({ length: 10 }, () => '<i></i>').join("");
    this.el.food.innerHTML = Array.from({ length: 10 }, () => '<i></i>').join("");
    this.el.hotbar.innerHTML = Array.from({ length: 9 }, (_, i) => `<button data-hot="${i}" class="slot"></button>`).join("");
  }

  bind() {
    const g = this.game;
    document.getElementById("play-survival").onclick = () => g.startSingle("survival");
    document.getElementById("play-creative").onclick = () => g.startSingle("creative");
    this.el.continueBtn.onclick = () => g.continueGame();
    document.getElementById("open-mp").onclick = () => this.showMp();
    document.getElementById("open-settings").onclick = () => this.showSettings(true);
    document.getElementById("host-survival").onclick = () => g.createRoom("survival");
    document.getElementById("host-creative").onclick = () => g.createRoom("creative");
    document.getElementById("join-btn").onclick = () => g.joinRoom(this.el.joinCode.value, document.getElementById("join-mode").value);
    document.getElementById("mp-back").onclick = () => this.showTitle();
    document.getElementById("copy-link").onclick = () => {
      const link = this.el.roomLink.value;
      navigator.clipboard?.writeText(link).then(() => this.toast("リンクをコピーしました")).catch(() => this.toast("リンクを選択してコピーしてください"));
    };
    document.getElementById("resume").onclick = () => g.resume();
    document.getElementById("pause-settings").onclick = () => this.showSettings(false);
    document.getElementById("save-exit").onclick = () => g.saveAndExit();
    document.getElementById("respawn").onclick = () => g.respawn();
    document.getElementById("settings-back").onclick = () => {
      this.el.settings.classList.add("hidden");
      if (g.running) this.el.pause.classList.remove("hidden");
      else this.el.title.classList.remove("hidden");
    };
    this.el.hotbar.addEventListener("click", (e) => {
      const btn = e.target.closest("[data-hot]");
      if (!btn || !g.player) return;
      g.player.inventory.selected = Number(btn.dataset.hot);
      this.refresh();
    });
    document.getElementById("btn-inventory").onclick = () => this.toggleInventory();
    this.bindSettings();
    const params = new URLSearchParams(location.search);
    if (params.get("room")) {
      this.el.joinCode.value = params.get("room").toUpperCase();
    }
  }

  bindSettings() {
    const s = this.game.settings;
    const bind = (id, key, parse) => {
      const el = document.getElementById(id);
      if (!el) return;
      el.value = s[key];
      el.onchange = () => {
        s[key] = parse(el);
        this.game.applySettings();
      };
    };
    bind("set-distance", "renderDistance", (el) => Number(el.value));
    bind("set-sens", "sensitivity", (el) => Number(el.value));
    bind("set-touch", "touchSensitivity", (el) => Number(el.value));
    bind("set-fov", "fov", (el) => Number(el.value));
    bind("set-vol", "volume", (el) => Number(el.value));
    bind("set-music", "music", (el) => Number(el.value));
    const bob = document.getElementById("set-bob");
    bob.checked = s.viewBob !== false;
    bob.onchange = () => {
      s.viewBob = bob.checked;
      this.game.applySettings();
    };
  }

  setIcons(tex) {
    this.tex = tex;
    const row = document.getElementById("logo-blocks");
    [1, 3, 7, 9, 12, 15, 20].forEach((id) => {
      const i = document.createElement("i");
      i.style.background = tex.iconStyle(tileOf(id, "side"));
      row.appendChild(i);
    });
  }

  async checkContinue() {
    const { hasSave } = await import("./save.js");
    const ok = await hasSave("latest");
    this.el.continueBtn.classList.toggle("hidden", !ok);
  }

  showTitle() {
    this.hideAll();
    this.el.title.classList.remove("hidden");
    this.checkContinue();
  }

  showMp() {
    this.hideAll();
    this.el.mp.classList.remove("hidden");
    const mpName = document.getElementById("mp-name");
    if (mpName && this.el.nameInput.value.trim()) mpName.value = this.el.nameInput.value.trim();
    const name = (mpName?.value || this.el.nameInput.value).trim();
    if (name) this.game.playerName = name.slice(0, 12);
  }

  showSettings(fromTitle) {
    this.el.title.classList.add("hidden");
    this.el.pause.classList.add("hidden");
    this.el.mp.classList.add("hidden");
    this.el.settings.classList.remove("hidden");
    this.fromTitle = fromTitle;
  }

  showLoading(text) {
    this.hideAll();
    this.el.loading.classList.remove("hidden");
    this.el.loadingText.textContent = text;
  }

  showGame() {
    this.hideAll();
    this.el.hud.classList.remove("hidden");
    this.refresh();
  }

  hideAll() {
    for (const el of [this.el.title, this.el.loading, this.el.hud, this.el.panel, this.el.pause, this.el.settings, this.el.death, this.el.mp]) {
      el.classList.add("hidden");
    }
  }

  blocking() {
    return !this.el.panel.classList.contains("hidden")
      || !this.el.pause.classList.contains("hidden")
      || !this.el.settings.classList.contains("hidden")
      || !this.el.death.classList.contains("hidden")
      || !this.el.title.classList.contains("hidden")
      || !this.el.mp.classList.contains("hidden");
  }

  toast(text) {
    this.el.toast.textContent = text;
    this.el.toast.classList.add("show");
    clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => this.el.toast.classList.remove("show"), 2200);
  }

  setRoom(code, link) {
    this.el.roomCode.textContent = code;
    this.el.roomLink.value = link;
    document.getElementById("room-box").classList.remove("hidden");
  }

  openPause() {
    if (!this.game.running) return;
    this.el.pause.classList.remove("hidden");
    this.game.releasePointer();
  }

  toggleInventory() {
    if (!this.el.panel.classList.contains("hidden") && this.kind === "inventory") {
      this.closePanel();
      return;
    }
    this.openPanel("inventory", null);
  }

  openPanel(kind, pos) {
    this.kind = kind;
    this.pos = pos;
    this.cursor = this.game.player.inventory.cursor;
    this.el.panel.classList.remove("hidden");
    this.game.releasePointer();
    this.renderPanel();
  }

  closePanel() {
    const player = this.game.player;
    if (!player) return;
    if (this.cursor) {
      const left = player.inventory.add(this.cursor.id, this.cursor.count);
      this.cursor = left ? { id: this.cursor.id, count: left } : null;
    }
    player.inventory.cursor = this.cursor;
    player.inventory.dumpCraft(this.kind === "craft" ? 3 : 2);
    this.kind = null;
    this.pos = null;
    this.el.panel.classList.add("hidden");
    this.el.panel.innerHTML = "";
    if (this.game.running && !this.mobile) this.game.capture();
  }

  refresh() {
    const player = this.game.player;
    if (!player || !this.tex) return;
    const hearts = [...this.el.hearts.children];
    for (let i = 0; i < 10; i++) {
      const v = player.health - i * 2;
      hearts[i].className = v >= 2 ? "full" : v >= 1 ? "half" : "";
    }
    const foods = [...this.el.food.children];
    for (let i = 0; i < 10; i++) {
      const v = player.hunger - i * 2;
      foods[i].className = v >= 2 ? "full" : v >= 1 ? "half" : "";
    }
    this.el.air.style.opacity = player.air < 300 ? "1" : "0";
    this.el.air.textContent = player.air < 300 ? "息 " + Math.ceil(player.air / 30) : "";
    const slots = [...this.el.hotbar.children];
    slots.forEach((slot, i) => {
      const item = player.inventory.slots[i];
      slot.classList.toggle("selected", i === player.inventory.selected);
      slot.innerHTML = "";
      if (!item) return;
      const icon = document.createElement("i");
      icon.style.background = this.tex.iconStyle(tileOf(item.id, "side"));
      slot.appendChild(icon);
      if (item.count > 1) {
        const n = document.createElement("b");
        n.textContent = item.count;
        slot.appendChild(n);
      }
    });
    if (!this.el.panel.classList.contains("hidden")) this.renderPanel();
  }

  flashItem(name) {
    this.el.itemName.textContent = name;
    this.el.itemName.classList.add("show");
    clearTimeout(this.itemTimer);
    this.itemTimer = setTimeout(() => this.el.itemName.classList.remove("show"), 1400);
  }

  renderPanel() {
    const player = this.game.player;
    const root = this.el.panel;
    root.innerHTML = "";
    const card = document.createElement("div");
    card.className = "card";
    const title = document.createElement("h2");
    title.textContent = this.kind === "craft" ? "作業台" : this.kind === "furnace" ? "かまど" : this.kind === "chest" ? "チェスト" : this.playerLabel();
    card.appendChild(title);

    if (this.kind === "inventory" || this.kind === "craft") {
      const size = this.kind === "craft" ? 3 : 2;
      const grid = size === 3 ? player.inventory.craft3 : player.inventory.craft2;
      card.appendChild(this.grid(size, grid, "craft", size));
      const result = matchCraft(grid.map((s) => s?.id || 0), size);
      const out = document.createElement("button");
      out.className = "slot result";
      if (result) this.fillSlot(out, { id: result.id, count: result.count });
      out.onclick = (e) => this.takeCraft(e, size, grid, result);
      const row = document.createElement("div");
      row.className = "craft-row";
      row.appendChild(card.querySelector(".grid"));
      const arrow = document.createElement("div");
      arrow.className = "arrow";
      arrow.textContent = "→";
      row.appendChild(arrow);
      row.appendChild(out);
      card.appendChild(row);
    } else if (this.kind === "furnace" && this.pos) {
      const f = this.game.world.ensureFurnace(this.pos.x, this.pos.y, this.pos.z);
      const box = document.createElement("div");
      box.className = "furnace-box";
      box.appendChild(this.oneSlot(f, "input", "素材"));
      box.appendChild(this.oneSlot(f, "fuel", "燃料"));
      const out = document.createElement("button");
      out.className = "slot";
      if (f.output) this.fillSlot(out, f.output);
      out.onclick = () => this.clickFurnaceOutput(f);
      box.appendChild(out);
      const bar = document.createElement("div");
      bar.className = "cook";
      bar.style.setProperty("--p", String(Math.min(1, f.cook / 200)));
      box.appendChild(bar);
      card.appendChild(box);
    } else if (this.kind === "chest" && this.pos) {
      const slots = this.game.world.ensureChest(this.pos.x, this.pos.y, this.pos.z);
      card.appendChild(this.grid(9, slots, "chest", 3));
    }

    if (player.creative && this.kind === "inventory") {
      const label = document.createElement("p");
      label.textContent = "クリエイティブ";
      card.appendChild(label);
      const wrap = document.createElement("div");
      wrap.className = "grid creative";
      for (const id of CREATIVE_IDS) {
        const btn = document.createElement("button");
        btn.className = "slot";
        this.fillSlot(btn, { id, count: 1 });
        btn.onclick = () => {
          player.inventory.add(id, blockOf(id)?.stack || 64);
          this.game.audio.play("click");
          this.refresh();
        };
        wrap.appendChild(btn);
      }
      card.appendChild(wrap);
    }

    const bagLabel = document.createElement("p");
    bagLabel.textContent = "インベントリ";
    card.appendChild(bagLabel);
    card.appendChild(this.grid(9, player.inventory.slots, "bag", 4));
    const close = document.createElement("button");
    close.className = "btn";
    close.textContent = "とじる";
    close.onclick = () => this.closePanel();
    card.appendChild(close);
    if (this.cursor) {
      const held = document.createElement("div");
      held.className = "cursor-item";
      this.fillSlot(held, this.cursor);
      card.appendChild(held);
    }
    root.appendChild(card);
    root.onclick = (e) => {
      if (e.target === root) this.closePanel();
    };
  }

  playerLabel() {
    return this.game.player.creative ? "クリエイティブ" : "インベントリ";
  }

  grid(cols, slots, bucket, rows = 1) {
    const wrap = document.createElement("div");
    wrap.className = "grid";
    wrap.style.gridTemplateColumns = `repeat(${cols}, 1fr)`;
    const count = bucket === "bag" ? 36 : cols * rows;
    for (let i = 0; i < count; i++) {
      const btn = document.createElement("button");
      btn.className = "slot";
      const item = slots[i];
      if (item) this.fillSlot(btn, item);
      btn.onmousedown = (e) => {
        e.preventDefault();
        this.clickBucket(bucket, slots, i, e.button === 2 ? 2 : 0);
      };
      btn.oncontextmenu = (e) => e.preventDefault();
      wrap.appendChild(btn);
    }
    return wrap;
  }

  oneSlot(furnace, key, label) {
    const wrap = document.createElement("label");
    wrap.className = "f-slot";
    wrap.textContent = label;
    const btn = document.createElement("button");
    btn.className = "slot";
    if (furnace[key]) this.fillSlot(btn, furnace[key]);
    btn.onmousedown = (e) => {
      e.preventDefault();
      const button = e.button === 2 ? 2 : 0;
      const res = clickStack(furnace[key], this.cursor, button);
      furnace[key] = res.slot;
      this.cursor = res.cursor;
      this.syncFurnace(furnace);
      this.refresh();
    };
    wrap.appendChild(btn);
    return wrap;
  }

  clickFurnaceOutput(furnace) {
    if (!furnace.output) return;
    if (this.cursor && this.cursor.id !== furnace.output.id) return;
    if (!this.cursor) this.cursor = { ...furnace.output };
    else this.cursor.count += furnace.output.count;
    furnace.output = null;
    this.syncFurnace(furnace);
    this.refresh();
  }

  clickBucket(bucket, slots, index, button) {
    if (bucket === "craft") {
      const res = clickStack(slots[index], this.cursor, button);
      slots[index] = res.slot;
      this.cursor = res.cursor;
    } else if (bucket === "chest") {
      const res = clickStack(slots[index], this.cursor, button);
      slots[index] = res.slot;
      this.cursor = res.cursor;
      this.game.net?.send({ t: "chest", key: keyOf(this.pos), slots });
    } else {
      const res = clickStack(slots[index], this.cursor, button);
      slots[index] = res.slot;
      this.cursor = res.cursor;
    }
    this.game.audio.play("click");
    this.refresh();
  }

  takeCraft(e, size, grid, result) {
    e.preventDefault();
    if (!result) return;
    const max = blockOf(result.id)?.stack || 64;
    if (this.cursor && (this.cursor.id !== result.id || this.cursor.count + result.count > max)) return;
    for (let i = 0; i < grid.length; i++) {
      if (!grid[i]) continue;
      grid[i].count -= 1;
      if (grid[i].count <= 0) grid[i] = null;
    }
    if (!this.cursor) this.cursor = { id: result.id, count: result.count };
    else this.cursor.count += result.count;
    this.game.audio.play("click");
    this.refresh();
  }

  syncFurnace(furnace) {
    if (!this.pos || !this.game.net) return;
    this.game.net.send({ t: "furnace", key: keyOf(this.pos), furnace });
  }

  fillSlot(el, item) {
    const icon = document.createElement("i");
    icon.style.background = this.tex.iconStyle(tileOf(item.id, item.id === 1 ? "top" : "side"));
    el.appendChild(icon);
    if (item.count > 1) {
      const n = document.createElement("b");
      n.textContent = item.count;
      el.appendChild(n);
    }
    el.title = blockOf(item.id)?.name || "";
  }

  updateNametags(list) {
    const root = this.el.nametags;
    root.innerHTML = "";
    for (const tag of list) {
      if (!tag) continue;
      const div = document.createElement("div");
      div.className = "tag";
      div.style.transform = `translate(${tag.x}px, ${tag.y}px)`;
      div.textContent = tag.name;
      root.appendChild(div);
    }
  }

  setDebug(text) {
    this.el.debug.textContent = text;
  }

  showDeath() {
    this.el.death.classList.remove("hidden");
    this.game.releasePointer();
  }
}

function keyOf(pos) {
  return pos.x + "," + pos.y + "," + pos.z;
}
