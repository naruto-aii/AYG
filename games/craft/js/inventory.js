import { blockOf } from "./blocks.js";

export function emptySlots(n) {
  return Array.from({ length: n }, () => null);
}

export function cloneSlot(slot) {
  return slot ? { id: slot.id, count: slot.count } : null;
}

export class Inventory {
  constructor() {
    this.slots = emptySlots(36);
    this.selected = 0;
    this.craft2 = emptySlots(4);
    this.craft3 = emptySlots(9);
    this.cursor = null;
  }

  held() {
    return this.slots[this.selected];
  }

  heldId() {
    return this.slots[this.selected]?.id || 0;
  }

  add(id, count) {
    const max = blockOf(id)?.stack || 64;
    const order = [];
    for (let i = 0; i < 36; i++) order.push(i);
    for (const i of order) {
      const s = this.slots[i];
      if (s && s.id === id && s.count < max) {
        const m = Math.min(max - s.count, count);
        s.count += m;
        count -= m;
        if (count <= 0) return 0;
      }
    }
    for (const i of order) {
      if (!this.slots[i]) {
        const m = Math.min(max, count);
        this.slots[i] = { id, count: m };
        count -= m;
        if (count <= 0) return 0;
      }
    }
    return count;
  }

  consumeHeld(creative) {
    if (creative) return;
    const s = this.slots[this.selected];
    if (!s) return;
    s.count -= 1;
    if (s.count <= 0) this.slots[this.selected] = null;
  }

  takeHeld(n, creative) {
    if (creative) return true;
    const s = this.slots[this.selected];
    if (!s || s.count < n) return false;
    s.count -= n;
    if (s.count <= 0) this.slots[this.selected] = null;
    return true;
  }

  dumpCraft(which) {
    const grid = which === 3 ? this.craft3 : this.craft2;
    for (let i = 0; i < grid.length; i++) {
      if (!grid[i]) continue;
      const left = this.add(grid[i].id, grid[i].count);
      if (left > 0) grid[i].count = left;
      else grid[i] = null;
    }
  }
}

export function clickStack(slot, cursor, button) {
  slot = cloneSlot(slot);
  cursor = cloneSlot(cursor);
  const maxOf = (id) => blockOf(id)?.stack || 64;
  if (button === 2) {
    if (!cursor && slot) {
      const take = Math.ceil(slot.count / 2);
      cursor = { id: slot.id, count: take };
      slot.count -= take;
      if (slot.count <= 0) slot = null;
      return { slot, cursor };
    }
    if (cursor && !slot) {
      slot = { id: cursor.id, count: 1 };
      cursor.count -= 1;
      if (cursor.count <= 0) cursor = null;
      return { slot, cursor };
    }
    if (cursor && slot && slot.id === cursor.id && slot.count < maxOf(slot.id)) {
      slot.count += 1;
      cursor.count -= 1;
      if (cursor.count <= 0) cursor = null;
      return { slot, cursor };
    }
    if (cursor && slot && slot.id !== cursor.id) return { slot: cursor, cursor: slot };
    return { slot, cursor };
  }
  if (!cursor && !slot) return { slot: null, cursor: null };
  if (!cursor) return { slot: null, cursor: slot };
  if (!slot) return { slot: cursor, cursor: null };
  if (slot.id === cursor.id) {
    const space = maxOf(slot.id) - slot.count;
    const move = Math.min(space, cursor.count);
    slot.count += move;
    cursor.count -= move;
    if (cursor.count <= 0) cursor = null;
    return { slot, cursor };
  }
  return { slot: cursor, cursor: slot };
}
