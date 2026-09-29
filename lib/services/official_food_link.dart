import 'package:url_launcher/url_launcher.dart';

import '../constants/official_food_copy.dart';

/// 文部科学省のページはアプリ内に埋め込まず、外部ブラウザで開く。
Future<bool> openMextFoodCompositionPage({
  Future<bool> Function(Uri uri, LaunchMode mode)? launch,
}) {
  final opener = launch ?? launchUrl;
  return opener(OfficialFoodCopy.sourcePage, LaunchMode.externalApplication);
}
