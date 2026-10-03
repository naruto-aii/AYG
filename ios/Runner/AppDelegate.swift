import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
  }
}
