/// Web起動時の診断用エラーコード（秘密情報は含めない）。
enum WebInitErrorCode {
  initConfigMissing('INIT_CONFIG_MISSING'),
  initSupabaseFailed('INIT_SUPABASE_FAILED'),
  initAuthStorageFailed('INIT_AUTH_STORAGE_FAILED'),
  initAuthRestoreFailed('INIT_AUTH_RESTORE_FAILED'),
  initRepositoryFailed('INIT_REPOSITORY_FAILED'),
  initSyncFailed('INIT_SYNC_FAILED'),
  initControllerFailed('INIT_CONTROLLER_FAILED'),
  initUnknown('INIT_UNKNOWN');

  const WebInitErrorCode(this.code);

  final String code;
}

class WebInitException implements Exception {
  WebInitException(this.code, {this.cause});

  final WebInitErrorCode code;
  final Object? cause;

  @override
  String toString() => code.code;
}

/// 起動診断の公開可能な状態（値そのものは含めない）。
class WebInitDiagnostics {
  bool supabaseUrlConfigured = false;
  bool supabaseAnonKeyConfigured = false;
  bool supabaseInitializeSuccess = false;
  bool authStorageAvailable = true;
  String authRestore = 'skipped';
  String initialSync = 'skipped';
  String? lastErrorCode;
}
