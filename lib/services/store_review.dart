import 'package:flutter/services.dart';

/// App Store のレビュー依頼。星も本文もアプリには返さない。
abstract class StoreReviewRequester {
  Future<void> request();
}

class NoOpStoreReviewRequester implements StoreReviewRequester {
  const NoOpStoreReviewRequester();

  @override
  Future<void> request() async {}
}

class MethodChannelStoreReviewRequester implements StoreReviewRequester {
  const MethodChannelStoreReviewRequester();

  static const channel = MethodChannel('com.narutoaii.ayg/store_review');

  @override
  Future<void> request() async {
    try {
      await channel.invokeMethod<void>('requestReview');
    } catch (_) {}
  }
}
