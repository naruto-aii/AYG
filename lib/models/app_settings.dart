/// アプリ全体の設定。
class AppSettings {
  const AppSettings({this.onboardingComplete = false});

  final bool onboardingComplete;

  AppSettings copyWith({bool? onboardingComplete}) {
    return AppSettings(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }
}
