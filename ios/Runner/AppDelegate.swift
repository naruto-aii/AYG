import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    UNUserNotificationCenter.current().delegate = DailyReminderBridge.shared
    return launched
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    DailyReminderBridge.shared.didRegister(deviceToken: deviceToken)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    DailyReminderBridge.shared.didFailToRegister()
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.narutoaii.ayg/lock_screen_meal",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "writeSnapshot":
        let snapshot = args?["snapshot"] as? String ?? ""
        let paid = args?["paid"] as? Bool ?? false
        LockScreenMealStore.write(snapshotJSON: snapshot, paid: paid)
        result(nil)
      case "setPaid":
        let paid = args?["paid"] as? Bool ?? false
        LockScreenMealStore.setPaid(paid)
        result(nil)
      case "readPending":
        result(LockScreenMealStore.readPendingJSON())
      case "acknowledge":
        let ids = args?["ids"] as? [String] ?? []
        LockScreenMealStore.acknowledge(ids: ids)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let siri = FlutterMethodChannel(
      name: "com.narutoaii.ayg/siri_voice",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    siri.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "writeCatalog":
        SiriVoiceStore.writeCatalog(args?["catalog"] as? String ?? "")
        result(nil)
      case "readPending":
        result(SiriVoiceStore.readPendingJSON())
      case "acknowledge":
        let ids = args?["ids"] as? [String] ?? []
        SiriVoiceStore.acknowledge(ids: ids)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    DailyReminderBridge.shared.attach(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// 通知の許可と APNs トークン。拒否でも例外にしない。
final class DailyReminderBridge: NSObject, UNUserNotificationCenterDelegate {
  static let shared = DailyReminderBridge()

  private let tokenDefaultsKey = "daily_calorie_reminder_device_token"
  private var pendingTokenResult: FlutterResult?
  private var latestToken: String?

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.narutoaii.ayg/daily_calorie_reminder",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "authorizationStatus":
        self.authorizationStatus(result)
      case "requestAuthorization":
        self.requestAuthorization(result)
      case "deviceToken":
        self.deviceToken(result)
      case "storedDeviceToken":
        result(UserDefaults.standard.string(forKey: self.tokenDefaultsKey))
      case "clearStoredDeviceToken":
        self.latestToken = nil
        UserDefaults.standard.removeObject(forKey: self.tokenDefaultsKey)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  func didRegister(deviceToken: Data) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    DispatchQueue.main.async {
      self.latestToken = hex
      UserDefaults.standard.set(hex, forKey: self.tokenDefaultsKey)
      self.pendingTokenResult?(hex)
      self.pendingTokenResult = nil
    }
  }

  func didFailToRegister() {
    DispatchQueue.main.async {
      self.pendingTokenResult?(nil)
      self.pendingTokenResult = nil
    }
  }

  private func authorizationStatus(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let name = Self.statusName(settings.authorizationStatus)
      DispatchQueue.main.async {
        result(name)
      }
    }
  }

  private func requestAuthorization(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
      DispatchQueue.main.async {
        if error != nil {
          result("denied")
          return
        }
        result(granted ? "authorized" : "denied")
      }
    }
  }

  private func deviceToken(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        let status = settings.authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else {
          result(nil)
          return
        }
        if let token = self.latestToken ?? UserDefaults.standard.string(forKey: self.tokenDefaultsKey) {
          result(token)
          return
        }
        self.pendingTokenResult?(nil)
        self.pendingTokenResult = result
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }

  private static func statusName(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined:
      return "notDetermined"
    case .denied:
      return "denied"
    case .authorized:
      return "authorized"
    case .provisional:
      return "provisional"
    case .ephemeral:
      return "ephemeral"
    @unknown default:
      return "unknown"
    }
  }
}
