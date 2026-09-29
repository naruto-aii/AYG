import 'package:web/web.dart' as web;

void openCurrentUrlInExternalBrowser() {
  web.window.open(web.window.location.href, '_blank');
}
