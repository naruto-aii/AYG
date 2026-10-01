import AppIntents
import SwiftUI
import WidgetKit

/// iOS 17 以降のロック画面（accessoryRectangular）に食事ボタンを3つ置く。
/// Siri、Watch、Live Activity は作らない。
struct LockScreenMealWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: LockScreenMealStore.widgetKind, provider: LockScreenMealProvider()) { entry in
      LockScreenMealWidgetView(entry: entry)
    }
    .configurationDisplayName("食事")
    .description("割り当てた食事テンプレートを、ロック画面から登録します。")
    .supportedFamilies([.accessoryRectangular])
  }
}

struct LockScreenMealEntry: TimelineEntry {
  let date: Date
  let paid: Bool
  let buttons: [LockScreenMealButton]
}

struct LockScreenMealProvider: TimelineProvider {
  func placeholder(in context: Context) -> LockScreenMealEntry {
    LockScreenMealEntry(date: Date(), paid: false, buttons: LockScreenMealButton.placeholders)
  }

  func getSnapshot(in context: Context, completion: @escaping (LockScreenMealEntry) -> Void) {
    completion(current())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenMealEntry>) -> Void) {
    completion(Timeline(entries: [current()], policy: .never))
  }

  private func current() -> LockScreenMealEntry {
    LockScreenMealEntry(
      date: Date(),
      paid: LockScreenMealStore.isPaid(),
      buttons: LockScreenMealStore.buttons()
    )
  }
}

struct LockScreenMealWidgetView: View {
  let entry: LockScreenMealEntry

  var body: some View {
    HStack(spacing: 6) {
      ForEach(entry.buttons) { button in
        Button(intent: RegisterLockScreenMealIntent(slot: button.slot)) {
          VStack(spacing: 1) {
            Text(button.displayLabel)
              .font(.system(size: 12, weight: .semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.6)
            if !entry.paid {
              Text("有料")
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
      }
    }
    .containerBackground(for: .widget) {
      AccessoryWidgetBackground()
    }
  }
}

/// ロック画面のボタン。ショートカットや Siri には出さない。
struct RegisterLockScreenMealIntent: AppIntent {
  static var title: LocalizedStringResource = "食事テンプレートを登録"
  static var openAppWhenRun = false
  static var isDiscoverable = false

  @Parameter(title: "ボタン")
  var slot: Int

  init() {
    self.slot = 0
  }

  init(slot: Int) {
    self.slot = slot
  }

  func perform() async throws -> some IntentResult {
    LockScreenMealStore.register(slot: slot)
    WidgetCenter.shared.reloadTimelines(ofKind: LockScreenMealStore.widgetKind)
    return .result()
  }
}

@main
struct LockScreenMealWidgetBundle: WidgetBundle {
  var body: some Widget {
    LockScreenMealWidget()
  }
}
