import AdServices
import AppIntents
import Flutter
import StoreKit
import UIKit
import WidgetKit

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
        if #available(iOS 17.0, *) {
          DispatchQueue.main.async {
            CalonaviListedShortcuts.updateAppShortcutParameters()
          }
        }
        result(nil)
      case "readPending":
        result(SiriVoiceStore.readPendingJSON())
      case "acknowledge":
        let ids = args?["ids"] as? [String] ?? []
        SiriVoiceStore.acknowledge(ids: ids)
        result(nil)
      case "readOpenSearch":
        result(SiriVoiceStore.readOpenSearch())
      case "clearOpenSearch":
        SiriVoiceStore.clearOpenSearch()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let review = FlutterMethodChannel(
      name: "com.narutoaii.ayg/store_review",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    review.setMethodCallHandler { call, result in
      switch call.method {
      case "requestReview":
        requestStoreReview()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let share = FlutterMethodChannel(
      name: "com.narutoaii.ayg/share_card",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    share.setMethodCallHandler { call, result in
      switch call.method {
      case "present":
        presentShareCard(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let analytics = FlutterMethodChannel(
      name: "com.narutoaii.ayg/analytics_native",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    analytics.setMethodCallHandler { call, result in
      handleAnalytics(call: call, result: result)
    }
  }
}

private func handleAnalytics(call: FlutterMethodCall, result: @escaping FlutterResult) {
  let args = call.arguments as? [String: Any]
  let defaults = LockScreenMealStore.defaults
  switch call.method {
  case "drainPending":
    result(readAnalyticsFiles())
  case "ackPending":
    deleteAnalyticsFiles(names: args?["names"] as? [String] ?? [])
    result(nil)
  case "setConsent":
    defaults?.set(args?["granted"] as? Bool ?? false, forKey: AnalyticsEventWriter.consentKey)
    result(nil)
  case "setOwnerUserId":
    if let userId = args?["userId"] as? String, !userId.isEmpty {
      defaults?.set(userId, forKey: AnalyticsEventWriter.ownerKey)
    } else {
      defaults?.removeObject(forKey: AnalyticsEventWriter.ownerKey)
    }
    result(nil)
  case "setInstallId":
    defaults?.set(args?["installId"] as? String ?? "", forKey: AnalyticsEventWriter.installKey)
    result(nil)
  case "nativeDroppedOverflow":
    let widget = defaults?.integer(forKey: "analyticsDroppedOverflow.widget") ?? 0
    let siri = defaults?.integer(forKey: "analyticsDroppedOverflow.siri") ?? 0
    result(widget + siri)
  case "deviceModel":
    var system = utsname()
    uname(&system)
    let machine = withUnsafePointer(to: &system.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(cString: $0)
      }
    }
    result(machine)
  case "widgetConfigurations":
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.getCurrentConfigurations { configs in
        switch configs {
        case .success(let info):
          var home = 0
          var lock = 0
          for item in info {
            if item.kind == LockScreenMealStore.homeWidgetKind {
              home += 1
            } else if item.kind == LockScreenMealStore.lockWidgetKind {
              lock += 1
            }
          }
          result(["home": home, "lock": lock, "HomeMealWidget": home, "LockScreenMealWidget": lock])
        case .failure:
          result([String: Int]())
        }
      }
    } else {
      result([String: Int]())
    }
  case "adServicesToken":
    if #available(iOS 14.3, *) {
      result(try? AAAttribution.attributionToken())
    } else {
      result(nil)
    }
  case "appTransactionInfo":
    if #available(iOS 16.0, *) {
      Task {
        do {
          let shared = try await AppTransaction.shared
          switch shared {
          case .verified(let transaction):
            let formatter = ISO8601DateFormatter()
            result([
              "originalPurchaseDate": formatter.string(from: transaction.originalPurchaseDate),
              "originalAppVersion": transaction.originalAppVersion,
              "environment": String(describing: transaction.environment),
            ])
          case .unverified:
            result(["environment": "unverified"])
          }
        } catch {
          result(["environment": "unverified"])
        }
      }
    } else {
      result(["environment": "unverified"])
    }
  default:
    result(FlutterMethodNotImplemented)
  }
}

private func analyticsDirectory() -> URL? {
  AnalyticsEventWriter.pendingDirectory()
}

private func readAnalyticsFiles() -> [[String: String]] {
  guard let directory = analyticsDirectory() else {
    return []
  }
  let urls = (try? FileManager.default.contentsOfDirectory(
    at: directory,
    includingPropertiesForKeys: nil
  )) ?? []
  var files: [[String: String]] = []
  for url in urls where url.pathExtension == "json" {
    guard let json = try? String(contentsOf: url, encoding: .utf8) else {
      continue
    }
    files.append(["name": url.lastPathComponent, "json": json])
  }
  return files
}

private func deleteAnalyticsFiles(names: [String]) {
  guard let directory = analyticsDirectory() else {
    return
  }
  for name in names {
    let url = directory.appendingPathComponent(name)
    try? FileManager.default.removeItem(at: url)
  }
}

/// システムにレビューを頼むだけ。星も本文も受け取らない。
private func requestStoreReview() {
  let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
  guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
    return
  }
  SKStoreReviewController.requestReview(in: scene)
}

/// 画像と文章を、iOS標準の共有シートに渡す。アプリは送り先を選ばない。
private func presentShareCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
  let args = call.arguments as? [String: Any]
  guard
    let png = args?["png"] as? FlutterStandardTypedData,
    let text = args?["text"] as? String,
    let image = UIImage(data: png.data)
  else {
    result(FlutterError(code: "bad_args", message: "png and text are required", details: nil))
    return
  }
  DispatchQueue.main.async {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    guard let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
      ?? scene?.windows.first?.rootViewController else {
      result(false)
      return
    }
    var presenter = root
    while let presented = presenter.presentedViewController {
      presenter = presented
    }
    let controller = UIActivityViewController(
      activityItems: [image, text],
      applicationActivities: nil
    )
    var finished = false
    controller.completionWithItemsHandler = { activityType, completed, _, _ in
      if finished {
        return
      }
      finished = true
      result([
        "completed": completed,
        "activityType": activityType ?? "",
      ])
    }
    if let popover = controller.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 1,
        height: 1
      )
      popover.permittedArrowDirections = []
    }
    presenter.present(controller, animated: true)
  }
}
