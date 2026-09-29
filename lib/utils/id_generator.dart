import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// アプリ全体で使う一意 ID（UUID v4）。
String generateUniqueId() => _uuid.v4();
