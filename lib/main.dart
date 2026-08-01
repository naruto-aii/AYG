import 'bootstrap/native_bootstrap.dart'
    if (dart.library.html) 'bootstrap/web_bootstrap.dart' as bootstrap;

Future<void> main() => bootstrap.bootstrapApp();
