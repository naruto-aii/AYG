import '../repositories/unavailable_subscription_repository.dart';

/// デモのあいだだけ、カロナビ+ に入っているものとして扱う。ストアには聞かない。
class DemoSubscriptionRepository extends UnavailableSubscriptionRepository {
  @override
  bool get isPlusActive => true;

  @override
  Stream<bool> get plusChanges => const Stream<bool>.empty();
}
