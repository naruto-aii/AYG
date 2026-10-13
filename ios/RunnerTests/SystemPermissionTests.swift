import XCTest

/// 使っている OS 権限の用途文言と、呼んでいない権限 API が Runner に無いこと。
final class SystemPermissionTests: XCTestCase {
  func testPurposeStringsMatchUsedPermissions() throws {
    let plist = try String(contentsOf: runnerFile("Info.plist"), encoding: .utf8)
    XCTAssertTrue(plist.contains("<key>NSHealthShareUsageDescription</key>"))
    XCTAssertTrue(plist.contains("<key>NSHealthUpdateUsageDescription</key>"))
    XCTAssertTrue(plist.contains("カロナビはヘルスケアへデータを書き込みません。"))
    XCTAssertTrue(plist.contains("<key>NSCameraUsageDescription</key>"))
    XCTAssertTrue(plist.contains("<key>NSSiriUsageDescription</key>"))
    XCTAssertTrue(plist.contains("生年月日、性別、身長、体重、アクティブエネルギー、ワークアウト"))
    XCTAssertFalse(plist.contains("ヘルスケアへ書き込みません"))
    XCTAssertFalse(plist.contains("NSPhotoLibraryUsageDescription"))
    XCTAssertFalse(plist.contains("NSPhotoLibraryAddUsageDescription"))
    XCTAssertFalse(plist.contains("NSUserTrackingUsageDescription"))
    XCTAssertFalse(plist.contains("NSMicrophoneUsageDescription"))
    XCTAssertFalse(plist.contains("NSSpeechRecognitionUsageDescription"))
    XCTAssertFalse(plist.contains("NSLocationWhenInUseUsageDescription"))
    XCTAssertFalse(plist.contains("NSLocationAlwaysAndWhenInUseUsageDescription"))
    XCTAssertFalse(plist.contains("NSContactsUsageDescription"))
    XCTAssertFalse(plist.contains("NSCalendarsUsageDescription"))
    XCTAssertFalse(plist.contains("NSBluetoothAlwaysUsageDescription"))
    XCTAssertFalse(plist.contains("NSMotionUsageDescription"))
    XCTAssertFalse(plist.contains("NSFaceIDUsageDescription"))
    XCTAssertFalse(plist.contains("診断"))
    XCTAssertFalse(plist.contains("治療"))

    let entitlements = try String(
      contentsOf: runnerFile("Runner.entitlements"),
      encoding: .utf8
    )
    XCTAssertTrue(entitlements.contains("com.apple.developer.healthkit"))
    XCTAssertFalse(entitlements.contains("com.apple.developer.siri"))

    let appDelegate = try String(contentsOf: runnerFile("AppDelegate.swift"), encoding: .utf8)
    XCTAssertTrue(appDelegate.contains("isExcludedFromBackup = true"))
    XCTAssertTrue(appDelegate.contains("com.narutoaii.ayg/backup_exclusion"))
  }

  func testRunnerDoesNotCallUnusedPermissionApis() throws {
    let runner = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Runner", isDirectory: true)
    let files = try FileManager.default.contentsOfDirectory(
      at: runner,
      includingPropertiesForKeys: nil
    )
    let swift = files.filter { $0.pathExtension == "swift" }
    XCTAssertFalse(swift.isEmpty)
    let banned = [
      "ATTrackingManager",
      "CLLocationManager",
      "SFSpeechRecognizer",
      "AVAudioSession",
      "UNUserNotificationCenter",
      "PHPhotoLibrary",
      "requestSiriAuthorization",
    ]
    for file in swift {
      let text = try String(contentsOf: file, encoding: .utf8)
      for token in banned {
        XCTAssertFalse(
          text.contains(token),
          "\(file.lastPathComponent) contains \(token)"
        )
      }
    }
  }

  private func runnerFile(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Runner", isDirectory: true)
      .appendingPathComponent(name)
  }
}
