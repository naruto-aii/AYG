class AppVersionPolicy {
  const AppVersionPolicy({
    required this.minimum,
    required this.recommended,
    required this.storeUrl,
  });

  final String minimum;
  final String recommended;
  final String storeUrl;
}

enum AppUpdateDecision { none, recommended, required }

AppUpdateDecision decideAppUpdate({
  required String current,
  required String minimum,
  required String recommended,
}) {
  if (_isBelow(current, minimum)) {
    return AppUpdateDecision.required;
  }
  if (_isBelow(current, recommended)) {
    return AppUpdateDecision.recommended;
  }
  return AppUpdateDecision.none;
}

class _ParsedVersion {
  const _ParsedVersion(
    this.major,
    this.minor,
    this.patch,
    this.build,
    this.hasBuild,
  );

  final int major;
  final int minor;
  final int patch;
  final int build;
  final bool hasBuild;
}

_ParsedVersion _parseVersion(String raw) {
  final trimmed = raw.trim();
  final plus = trimmed.indexOf('+');
  final numbers = plus >= 0 ? trimmed.substring(0, plus) : trimmed;
  final buildText = plus >= 0 ? trimmed.substring(plus + 1).trim() : '';
  final parts = numbers.split('.');
  int piece(int index) {
    if (index >= parts.length) {
      return 0;
    }
    return int.tryParse(parts[index].trim()) ?? 0;
  }

  return _ParsedVersion(
    piece(0),
    piece(1),
    piece(2),
    int.tryParse(buildText) ?? 0,
    plus >= 0,
  );
}

bool _isBelow(String current, String policy) {
  final left = _parseVersion(current);
  final right = _parseVersion(policy);
  if (left.major != right.major) {
    return left.major < right.major;
  }
  if (left.minor != right.minor) {
    return left.minor < right.minor;
  }
  if (left.patch != right.patch) {
    return left.patch < right.patch;
  }
  if (!right.hasBuild) {
    return false;
  }
  return left.build < right.build;
}
