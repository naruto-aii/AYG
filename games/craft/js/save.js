const DB = "terrablock";
const STORE = "worlds";

function openDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB, 1);
    req.onupgradeneeded = () => {
      req.result.createObjectStore(STORE);
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function saveWorld(slot, data) {
  try {
    const db = await openDB();
    await new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      tx.objectStore(STORE).put(data, slot);
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
    });
    db.close();
    return true;
  } catch {
    try {
      localStorage.setItem("terrablock-backup", JSON.stringify({
        seed: data.seed,
        time: data.time,
        player: data.player,
      }));
    } catch { /* ignore quota */ }
    return false;
  }
}

export async function loadWorld(slot) {
  try {
    const db = await openDB();
    const value = await new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, "readonly");
      const req = tx.objectStore(STORE).get(slot);
      req.onsuccess = () => resolve(req.result || null);
      req.onerror = () => reject(req.error);
    });
    db.close();
    return value || null;
  } catch {
    return null;
  }
}

export async function hasSave(slot) {
  const data = await loadWorld(slot);
  return !!data;
}

export function loadSettings() {
  try {
    return JSON.parse(localStorage.getItem("terrablock-settings") || "{}");
  } catch {
    return {};
  }
}

export function saveSettings(settings) {
  localStorage.setItem("terrablock-settings", JSON.stringify(settings));
}
