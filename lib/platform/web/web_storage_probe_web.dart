import 'package:web/web.dart' as web;

bool probeWebLocalStorage() {
  try {
    const key = '__ayg_storage_probe__';
    web.window.localStorage.setItem(key, '1');
    web.window.localStorage.removeItem(key);
    return true;
  } catch (_) {
    return false;
  }
}
