import AppIntents
import SwiftUI
import WidgetKit

/// ホーム画面の大ウィジェットと、ロック画面の横長ウィジェット。
///
/// ボタンは `openAppWhenRun = false`。押してもアプリは開かず、割り当てた
/// テンプレートを1件だけ追記する。未課金のときは追記しない。
/// 「有料」とは書かない。作成時の説明はアプリ内のポップアップに置く。
/// このボタンは Siri に出さない。Watch と Live Activity は作らない。

struct MealWidgetFigures {
  var remaining: Int?
  var intake: Int?
  var burn: Int?
}

struct MealWidgetEntry: TimelineEntry {
  let date: Date
  let figures: MealWidgetFigures
  let buttons: [LockScreenMealButton]
}

enum MealWidgetTimeline {
  static func entry(buttons: [LockScreenMealButton]) -> MealWidgetEntry {
    let figures = LockScreenMealStore.figures()
    return MealWidgetEntry(
      date: Date(),
      figures: MealWidgetFigures(
        remaining: figures.remaining,
        intake: figures.intake,
        burn: figures.burn
      ),
      buttons: buttons
    )
  }
}

struct HomeMealWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: LockScreenMealStore.homeWidgetKind, provider: HomeMealProvider()) { entry in
      HomeMealWidgetView(entry: entry)
    }
    .configurationDisplayName("カロナビ")
    .description("残りカロリー、摂取、消費と、食事テンプレートのボタンです。")
    .supportedFamilies([.systemLarge])
  }
}

struct HomeMealProvider: TimelineProvider {
  func placeholder(in context: Context) -> MealWidgetEntry {
    MealWidgetEntry(date: Date(), figures: MealWidgetFigures(), buttons: LockScreenMealButton.homePlaceholders)
  }

  func getSnapshot(in context: Context, completion: @escaping (MealWidgetEntry) -> Void) {
    completion(MealWidgetTimeline.entry(buttons: LockScreenMealStore.homeButtons()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MealWidgetEntry>) -> Void) {
    let entry = MealWidgetTimeline.entry(buttons: LockScreenMealStore.homeButtons())
    completion(Timeline(entries: [entry], policy: .never))
  }
}

struct LockScreenMealWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: LockScreenMealStore.lockWidgetKind, provider: LockMealProvider()) { entry in
      LockMealWidgetView(entry: entry)
    }
    .configurationDisplayName("カロナビ")
    .description("残り、摂取、消費と、朝・昼・夜のボタンです。")
    .supportedFamilies([.accessoryRectangular])
  }
}

struct LockMealProvider: TimelineProvider {
  func placeholder(in context: Context) -> MealWidgetEntry {
    MealWidgetEntry(date: Date(), figures: MealWidgetFigures(), buttons: LockScreenMealButton.lockPlaceholders)
  }

  func getSnapshot(in context: Context, completion: @escaping (MealWidgetEntry) -> Void) {
    completion(MealWidgetTimeline.entry(buttons: LockScreenMealStore.lockButtons()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MealWidgetEntry>) -> Void) {
    let entry = MealWidgetTimeline.entry(buttons: LockScreenMealStore.lockButtons())
    completion(Timeline(entries: [entry], policy: .never))
  }
}

private enum MealWidgetPalette {
  static let ink = Color(red: 46 / 255, green: 58 / 255, blue: 51 / 255)
  static let muted = Color(red: 124 / 255, green: 136 / 255, blue: 128 / 255)
  static let flame = Color(red: 246 / 255, green: 137 / 255, blue: 43 / 255)
  static let homeButtonColors: [Color] = [
    Color(red: 246 / 255, green: 137 / 255, blue: 43 / 255),
    Color(red: 60 / 255, green: 135 / 255, blue: 90 / 255),
    Color(red: 27 / 255, green: 94 / 255, blue: 57 / 255),
    Color(red: 201 / 255, green: 106 / 255, blue: 18 / 255),
    Color(red: 90 / 255, green: 162 / 255, blue: 119 / 255),
  ]

  static func kcal(_ value: Int?) -> String {
    guard let value else {
      return "—"
    }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "ja_JP")
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
  }
}

struct HomeMealWidgetView: View {
  let entry: MealWidgetEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 8) {
        Image(systemName: "flame.fill")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(MealWidgetPalette.flame)
        Text("カロナビ")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(MealWidgetPalette.ink)
      }
      HStack(alignment: .bottom, spacing: 12) {
        homeFigure(title: "残りカロリー", value: entry.figures.remaining, prominent: true)
        Spacer(minLength: 4)
        homeFigure(title: "摂取", value: entry.figures.intake, prominent: false)
        homeFigure(title: "消費", value: entry.figures.burn, prominent: false)
      }
      Spacer(minLength: 8)
      HStack(spacing: 6) {
        ForEach(Array(entry.buttons.prefix(5).enumerated()), id: \.element.id) { index, button in
          Button(intent: RegisterMealWidgetIntent(surface: "home", slot: button.slot)) {
            Text(button.displayLabel)
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(Color.white)
              .lineLimit(2)
              .minimumScaleFactor(0.55)
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity, minHeight: 52, maxHeight: .infinity)
              .padding(.horizontal, 2)
              .background(
                MealWidgetPalette.homeButtonColors[index % MealWidgetPalette.homeButtonColors.count],
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
              )
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(16)
    .containerBackground(Color.white, for: .widget)
  }

  private func homeFigure(title: String, value: Int?, prominent: Bool) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(MealWidgetPalette.muted)
        .lineLimit(1)
      Text(MealWidgetPalette.kcal(value))
        .font(.system(size: prominent ? 36 : 22, weight: .bold))
        .foregroundStyle(MealWidgetPalette.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
  }
}

struct LockMealWidgetView: View {
  let entry: MealWidgetEntry

  var body: some View {
    VStack(spacing: 6) {
      HStack(spacing: 4) {
        lockFigure(title: "残り", value: entry.figures.remaining)
        lockFigure(title: "摂取", value: entry.figures.intake)
        lockFigure(title: "消費", value: entry.figures.burn)
      }
      HStack(spacing: 4) {
        ForEach(entry.buttons.prefix(3)) { button in
          Button(intent: RegisterMealWidgetIntent(surface: "lock", slot: button.slot)) {
            Text(button.displayLabel)
              .font(.system(size: 12, weight: .semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.5)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .containerBackground(for: .widget) {
      AccessoryWidgetBackground()
    }
  }

  private func lockFigure(title: String, value: Int?) -> some View {
    VStack(spacing: 0) {
      Text(title)
        .font(.system(size: 10, weight: .medium))
        .lineLimit(1)
      Text(MealWidgetPalette.kcal(value))
        .font(.system(size: 14, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
    .frame(maxWidth: .infinity)
  }
}

/// ホームとロック画面のボタン。ショートカットや Siri には出さない。
/// 食事と運動の復唱登録は、アプリ本体の別の App Intent。
struct RegisterMealWidgetIntent: AppIntent {
  static var title: LocalizedStringResource = "食事テンプレートを登録"
  static var openAppWhenRun = false
  static var isDiscoverable = false

  @Parameter(title: "画面")
  var surface: String

  @Parameter(title: "ボタン")
  var slot: Int

  init() {
    self.surface = "lock"
    self.slot = 0
  }

  init(surface: String, slot: Int) {
    self.surface = surface
    self.slot = slot
  }

  func perform() async throws -> some IntentResult {
    LockScreenMealStore.register(surface: surface, slot: slot)
    LockScreenMealStore.reloadWidgets()
    return .result()
  }
}

@main
struct CalonaviWidgetBundle: WidgetBundle {
  var body: some Widget {
    HomeMealWidget()
    LockScreenMealWidget()
  }
}
