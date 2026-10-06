import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'share_card_content.dart';

enum ShareResult { sent, cancelled, failed }

const shareCardChannel = MethodChannel('com.narutoaii.ayg/share_card');

typedef SharePresenter = Future<bool> Function(Uint8List png, String text);

/// 画面に出しているカードをPNGにする。
Future<Uint8List> pngBytesFromBoundary(
  GlobalKey boundaryKey, {
  double pixelRatio = 3,
}) async {
  final boundary = boundaryKey.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) {
    throw StateError('共有画像を作れませんでした');
  }
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('共有画像を作れませんでした');
    }
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// iOSの共有シート。画像と、画像が無くても読める文章を一緒に渡す。
Future<bool> presentIosShareSheet(Uint8List png, String text) async {
  final sent = await shareCardChannel.invokeMethod<bool>('present', {
    'png': png,
    'text': text,
  });
  return sent ?? false;
}

/// 画面の外にカードを一度描いてから、共有シートを開く。
Future<ShareResult> presentCapturedShareCard({
  required BuildContext context,
  required ShareCardContent content,
  required Widget card,
  required VoidCallback onSent,
  SharePresenter? present,
}) async {
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: -4000,
      top: 0,
      child: RepaintBoundary(
        key: key,
        child: SizedBox(
          width: shareCardSize,
          height: shareCardSize,
          child: card,
        ),
      ),
    ),
  );
  Overlay.of(context).insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    return await sendShareCard(
      content: content,
      boundaryKey: key,
      onSent: onSent,
      present: present,
    );
  } finally {
    entry.remove();
  }
}

Future<ShareResult> sendShareCard({
  required ShareCardContent content,
  required GlobalKey boundaryKey,
  required VoidCallback onSent,
  SharePresenter? present,
}) async {
  try {
    final png = await pngBytesFromBoundary(boundaryKey);
    final sent = await (present ?? presentIosShareSheet)(png, content.message);
    if (!sent) {
      return ShareResult.cancelled;
    }
    onSent();
    return ShareResult.sent;
  } catch (_) {
    return ShareResult.failed;
  }
}
