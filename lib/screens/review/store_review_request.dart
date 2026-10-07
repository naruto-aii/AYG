import 'package:flutter/material.dart';

import '../../repositories/review_prompt_store.dart';
import '../../services/analytics/catalog_actions.dart';
import '../../services/store_review.dart';

/// 依頼は1回だけ。断ったら再び出さない。書いたレビューは受け取らない。
Future<void> presentStoreReviewRequest({
  required BuildContext context,
  required ReviewPromptStore store,
  StoreReviewRequester requester = const MethodChannelStoreReviewRequester(),
}) async {
  if (!context.mounted) {
    return;
  }
  final closed = await store.isClosed();
  final due = closed ? false : await store.hasDue();
  if (closed || !due || !context.mounted) {
    return;
  }
  CatalogActions.reviewPromptShown('streak');
  final review = await showDialog<bool>(
      routeSettings: const RouteSettings(name: 'store_review_request_showDialog_0'),
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        key: const Key('store_review_request'),
        title: const Text('レビューをお願いできますか'),
        content: const Text(
          '7日続けて記録したあと、またはウィジェットか音声で登録したあとに出します。断ると次は出ません。評価の内容はアプリでは受け取りません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('断る'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('レビューする'),
          ),
        ],
      );
    },
  );
  if (review == true) {
    CatalogActions.reviewPromptAnswer('review');
    await store.markAsked();
    await requester.request();
    return;
  }
  CatalogActions.reviewPromptAnswer('decline');
  await store.markDeclined();
}
