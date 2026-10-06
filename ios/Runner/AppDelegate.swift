import Flutter
import StoreKit
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
    controller.completionWithItemsHandler = { _, completed, _, _ in
      if finished {
        return
      }
      finished = true
      result(completed)
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
