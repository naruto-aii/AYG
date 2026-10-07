import 'package:flutter/widgets.dart';

import 'analytics_service.dart';

/// push・pop・replace で screen_view を残す。名前の無い経路は送らない。
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver({required AnalyticsService service, DateTime Function()? clock})
    : _service = service,
      _clock = clock ?? DateTime.now;

  final AnalyticsService _service;
  final DateTime Function() _clock;
  final List<String> unnamed = [];
  DateTime? _shownAt;
  String? _current;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _view(route, previousRoute, 'push');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _view(previousRoute, route, 'pop');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _view(newRoute, oldRoute, 'push');
  }

  void noteTab(String name) {
    _emit(name, null, 'tab');
  }

  void _view(Route<dynamic>? route, Route<dynamic>? previous, String via) {
    final name = route?.settings.name;
    if (route is PageRoute && (name == null || name.isEmpty)) {
      unnamed.add(route.runtimeType.toString());
      return;
    }
    if (name == null || name.isEmpty) {
      return;
    }
    _emit(name, previous?.settings.name, via);
  }

  void _emit(String name, String? previous, String via) {
    final now = _clock();
    final dwell = _shownAt == null ? null : now.difference(_shownAt!).inMilliseconds;
    _service.currentScreen = name;
    _service.currentScreenSince = now;
    _shownAt = now;
    _current = name;
    _service.track('screen_view', {
      'screen': name,
      'previous_screen': previous,
      'previous_screen_dwell_ms': dwell,
      'via': via,
    });
  }

  String? get current => _current;
}
