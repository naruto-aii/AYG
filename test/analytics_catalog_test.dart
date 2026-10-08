import 'dart:convert';
import 'dart:io';

import 'package:ayg/services/analytics/event_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event names match the catalog and the database pattern', () {
    final raw = File('docs/analytics/events_catalog.csv').readAsBytesSync();
    final text = utf8.decode(raw).replaceFirst('\uFEFF', '');
    final lines = text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final names = [
      for (final line in lines.skip(1)) line.split(',').first.trim(),
    ];
    expect(names, AnalyticsEventNames.all);
    expect(names.toSet().length, 102);
    final pattern = RegExp(r'^[a-z][a-z0-9_]{1,62}$');
    for (final name in names) {
      expect(pattern.hasMatch(name), isTrue, reason: name);
      expect(
        AnalyticsEventNames.allowedProps.containsKey(name),
        isTrue,
        reason: name,
      );
    }
  });
}
