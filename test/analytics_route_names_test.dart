import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every page route, dialog, and sheet has a name', () {
    final missing = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) {
        continue;
      }
      final text = file.readAsStringSync();
      for (final name in [
        'MaterialPageRoute',
        'showDialog',
        'showModalBottomSheet',
      ]) {
        final key = name == 'MaterialPageRoute'
            ? 'settings:'
            : 'routeSettings:';
        for (final span in _calls(text, name)) {
          if (!_topLevelHas(span, key)) {
            missing.add('${file.path} $name');
          }
        }
      }
    }
    expect(missing, isEmpty);
  });
}

List<String> _calls(String text, String name) {
  final found = <String>[];
  var i = 0;
  while (true) {
    final j = text.indexOf(name, i);
    if (j < 0) {
      break;
    }
    if (j > 0 && (RegExp(r'[A-Za-z0-9_]').hasMatch(text[j - 1]))) {
      i = j + 1;
      continue;
    }
    var k = j + name.length;
    while (k < text.length && text[k].trim().isEmpty) {
      k++;
    }
    if (k < text.length && text[k] == '<') {
      var depth = 0;
      while (k < text.length) {
        if (text[k] == '<') {
          depth++;
        } else if (text[k] == '>') {
          depth--;
          if (depth == 0) {
            k++;
            break;
          }
        }
        k++;
      }
    }
    while (k < text.length && text[k].trim().isEmpty) {
      k++;
    }
    if (k >= text.length || text[k] != '(') {
      i = j + 1;
      continue;
    }
    final start = k;
    var depth = 0;
    var k2 = k;
    String? quote;
    var escape = false;
    while (k2 < text.length) {
      final ch = text[k2];
      if (quote != null) {
        if (escape) {
          escape = false;
        } else if (ch == r'\') {
          escape = true;
        } else if (ch == quote) {
          quote = null;
        }
        k2++;
        continue;
      }
      if (ch == "'" || ch == '"') {
        quote = ch;
        k2++;
        continue;
      }
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
        if (depth == 0) {
          break;
        }
      }
      k2++;
    }
    found.add(text.substring(start, k2 + 1));
    i = k2 + 1;
  }
  return found;
}

bool _topLevelHas(String span, String key) {
  var depth = 0;
  String? quote;
  var escape = false;
  final buf = StringBuffer();
  final parts = <String>[];
  for (final ch in span.split('')) {
    if (quote != null) {
      buf.write(ch);
      if (escape) {
        escape = false;
      } else if (ch == r'\') {
        escape = true;
      } else if (ch == quote) {
        quote = null;
      }
      continue;
    }
    if (ch == "'" || ch == '"') {
      quote = ch;
      buf.write(ch);
      continue;
    }
    if (ch == '(') {
      depth++;
      if (depth > 1) {
        buf.write(ch);
      }
      continue;
    }
    if (ch == ')') {
      depth--;
      if (depth == 0) {
        parts.add(buf.toString());
        break;
      }
      buf.write(ch);
      continue;
    }
    if (ch == ',' && depth == 1) {
      parts.add(buf.toString());
      buf.clear();
      continue;
    }
    buf.write(ch);
  }
  return parts.any((part) => part.trimLeft().startsWith(key));
}
