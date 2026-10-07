import AppIntents
import SwiftUI
import WidgetKit

/// ホーム画面の大ウィジェットと、ロック画面の横長ウィジェット。
///
/// 見た目の仕様は `docs/design/widget/README.md`（モックは同じフォルダの `mockup.html`）。
/// 色・サイズ・ラベルの文字数ルールを変えるときは、README も同じ値に直す。
///
/// ボタンは `openAppWhenRun = false`。押してもアプリは開かず、割り当てた
/// テンプレートを1件だけ追記する。未課金のときは追記しない。
/// 「有料」とは書かない。作成時の説明はアプリ内のポップアップに置く。
/// このボタンは Siri に出さない。Watch と Live Activity は作らない。

struct MealWidgetFigures {
  var remaining: Int?
  var intake: Int?
  var burn: Int?
  var target: Int?
  var overage: Int?

  var isOver: Bool { (overage ?? 0) > 0 }

  /// リングの塗り（0.0〜1.0）。中央の「今日あと」と同じ数字から作る。
  ///
  /// 割合 = 摂取 ÷（摂取 + 残り）。摂取 + 残り は「目標 + 運動などの消費」で、
  /// 一周ちょうど塗られたとき＝あと 0kcal＝今日の目標に届いた、になる。丸めない。
  /// 超過は一周。目標が 0 以下なら 0。残りが無い古いデータだけ摂取 ÷ 目標。
  /// Dart の `MealWidgetFigures.ringProgress`（`calorieRingProgress`）と同じ。
  var progress: Double {
    MealWidgetFigures.ringFraction(intake: intake, remaining: remaining, target: target, overage: overage)
  }

  static func ringFraction(intake: Int?, remaining: Int?, target: Int?, overage: Int?) -> Double {
    if let target, target <= 0 {
      return 0
    }
    if (overage ?? 0) > 0 {
      return 1
    }
    guard let intake, intake > 0 else {
      return 0
    }
    if let remaining {
      let budget = Double(intake) + Double(max(remaining, 0))
      guard budget > 0 else {
        return 0
      }
      return min(max(Double(intake) / budget, 0), 1)
    }
    guard let target, target > 0 else {
      return 0
    }
    return min(max(Double(intake) / Double(target), 0), 1)
  }

  /// リング中央とロック画面の見出し。超過の日はアプリのホームと同じく「超過」を出す。
  var headline: String { isOver ? "超過" : "今日あと" }
  var shortHeadline: String { isOver ? "超過" : "あと" }
  var headlineValue: Int? { isOver ? overage : remaining }
}

struct MealWidgetEntry: TimelineEntry {
  let date: Date
  let figures: MealWidgetFigures
  let buttons: [LockScreenMealButton]
}

enum MealWidgetTimeline {
  /// [date] の時点で見せる数字。保存日が [date] の日と違えば今日の初期状態になる。
  static func entry(buttons: [LockScreenMealButton], at date: Date = Date()) -> MealWidgetEntry {
    let figures = LockScreenMealStore.figures(now: date)
    return MealWidgetEntry(
      date: date,
      figures: MealWidgetFigures(
        remaining: figures.remaining,
        intake: figures.intake,
        burn: figures.burn,
        target: figures.target,
        overage: figures.overage
      ),
      buttons: buttons
    )
  }

  /// 今の表示と、次のローカル 0 時の表示。0 時を過ぎたら iOS が次のタイムラインを取りに来る（`.atEnd`）。
  /// アプリを開かなくても、日付が変わると摂取 0・あと＝目標・リング空に切り替わる。
  static func timeline(buttons: [LockScreenMealButton], now: Date = Date()) -> Timeline<MealWidgetEntry> {
    let midnight = MealWidgetDay.nextMidnight(after: now)
    return Timeline(
      entries: [entry(buttons: buttons, at: now), entry(buttons: buttons, at: midnight)],
      policy: .atEnd
    )
  }
}

struct HomeMealWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: LockScreenMealStore.homeWidgetKind, provider: HomeMealProvider()) { entry in
      HomeMealWidgetView(entry: entry)
    }
    .configurationDisplayName("カロナビ")
    .description("残りカロリーに加え、食事と運動をワンタッチで登録します。枠は食事と運動を自由に組み合わせられます。")
    .supportedFamilies([.systemLarge])
    .contentMarginsDisabled()
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
    completion(MealWidgetTimeline.timeline(buttons: LockScreenMealStore.homeButtons()))
  }
}

struct LockScreenMealWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: LockScreenMealStore.lockWidgetKind, provider: LockMealProvider()) { entry in
      LockMealWidgetView(entry: entry)
    }
    .configurationDisplayName("カロナビ")
    .description("残りカロリーに加え、ホームの1〜3枠目をワンタッチで登録します。")
    .supportedFamilies([.accessoryRectangular])
    .contentMarginsDisabled()
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
    completion(MealWidgetTimeline.timeline(buttons: LockScreenMealStore.lockButtons()))
  }
}

// MARK: - デザイントークン（lib/theme/app_colors.dart と同じ値）

private enum MealWidgetPalette {
  static let green900 = Color(red: 20 / 255, green: 82 / 255, blue: 47 / 255)
  static let green800 = Color(red: 27 / 255, green: 94 / 255, blue: 57 / 255)
  static let green600 = Color(red: 60 / 255, green: 135 / 255, blue: 90 / 255)
  static let green300 = Color(red: 168 / 255, green: 208 / 255, blue: 184 / 255)
  static let orange500 = Color(red: 246 / 255, green: 137 / 255, blue: 43 / 255)

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

/// アプリと同じ Zen Maru Gothic。フォントはこの拡張に同梱し、Info.plist の UIAppFonts で読み込む。
/// 文字の大きさで並びが崩れないよう、ダイナミックタイプでは拡大しない。
private enum MealWidgetFont {
  static func medium(_ size: CGFloat) -> Font { .custom("ZenMaruGothic-Medium", fixedSize: size) }
  static func bold(_ size: CGFloat) -> Font { .custom("ZenMaruGothic-Bold", fixedSize: size) }
}

// MARK: - ホーム画面（systemLarge）

struct HomeMealWidgetView: View {
  let entry: MealWidgetEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 6) {
        Circle()
          .fill(MealWidgetPalette.orange500)
          .frame(width: 8, height: 8)
        Text("カロナビ")
          .font(MealWidgetFont.bold(13))
          .foregroundStyle(Color.white.opacity(0.92))
      }
      HStack(spacing: 18) {
        HomeCalorieRing(figures: entry.figures)
          .frame(width: 132, height: 132)
        VStack(alignment: .leading, spacing: 10) {
          homeStat(symbol: "fork.knife", title: "摂取", value: entry.figures.intake)
          Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
          homeStat(symbol: "figure.run", title: "消費", value: entry.figures.burn)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.top, 12)
      Spacer(minLength: 0)
      Text("タップで記録")
        .font(MealWidgetFont.medium(11))
        .foregroundStyle(Color.white.opacity(0.6))
        .padding(.horizontal, 2)
        .padding(.bottom, 8)
      HStack(spacing: 6) {
        ForEach(entry.buttons.prefix(5)) { button in
          Button(intent: RegisterMealWidgetIntent(surface: "home", slot: button.slot, kind: button.kind)) {
            HomeTile(label: button.displayLabel)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .foregroundStyle(Color.white)
    .padding(EdgeInsets(top: 18, leading: 18, bottom: 16, trailing: 18))
    .containerBackground(for: .widget) {
      HomeWidgetBackground()
    }
  }

  private func homeStat(symbol: String, title: String, value: Int?) -> some View {
    HStack(spacing: 10) {
      Image(systemName: symbol)
        .font(.system(size: 15, weight: .semibold))
        .frame(width: 32, height: 32)
        .background(Color.white.opacity(0.12), in: Circle())
      VStack(alignment: .leading, spacing: 0) {
        Text(title)
          .font(MealWidgetFont.medium(11))
          .foregroundStyle(Color.white.opacity(0.65))
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(MealWidgetPalette.kcal(value))
            .font(MealWidgetFont.bold(22))
            .tracking(-0.44)
          Text("kcal")
            .font(MealWidgetFont.bold(11))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      }
    }
  }
}

/// green600 → green800 → green900 の放射グラデーションに、右上の淡い光を重ねる。
private struct HomeWidgetBackground: View {
  var body: some View {
    ZStack(alignment: .topTrailing) {
      RadialGradient(
        stops: [
          .init(color: MealWidgetPalette.green600, location: 0),
          .init(color: MealWidgetPalette.green800, location: 0.45),
          .init(color: MealWidgetPalette.green900, location: 1),
        ],
        center: .topTrailing,
        startRadius: 0,
        endRadius: 440
      )
      Circle()
        .fill(
          RadialGradient(
            colors: [MealWidgetPalette.green300.opacity(0.25), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 70
          )
        )
        .frame(width: 200, height: 200)
        .offset(x: 60, y: -60)
    }
  }
}

/// 丸い端の線で、見た目の塗りが 0〜progress ちょうどになる trim の範囲。
/// 丸い端は両側に線幅の半分ずつはみ出すので、その分だけ両端を内側に寄せる。
/// 寄せないと約97%で輪が閉じて見える。Dart の `ringTrimRange` と同じ。
enum MealWidgetRingTrim {
  static func capFraction(radius: Double, lineWidth: Double) -> Double {
    guard radius > 0, lineWidth > 0 else {
      return 0
    }
    return lineWidth / (2 * Double.pi * radius)
  }

  /// 0 以下は nil（描かない）。1 以上は一周。丸い端より短いときは 0〜progress のまま。
  static func range(progress: Double, capFraction: Double) -> (from: Double, to: Double)? {
    guard progress.isFinite, progress > 0 else {
      return nil
    }
    if progress >= 1 {
      return (0, 1)
    }
    if progress <= capFraction {
      return (0, progress)
    }
    let half = capFraction / 2
    return (half, progress - half)
  }
}

/// アプリの `CalorieRing` と同じ形。12時から反時計回りに伸び、オレンジの点は右上（-38°）に固定する。
/// 超過の日は、アプリと同じくリングをオレンジにする。
private struct HomeCalorieRing: View {
  let figures: MealWidgetFigures

  private let radius: CGFloat = 58
  private let lineWidth: CGFloat = 10

  var body: some View {
    let angle = 38 * Double.pi / 180
    let trim = MealWidgetRingTrim.range(
      progress: figures.progress,
      capFraction: MealWidgetRingTrim.capFraction(radius: Double(radius), lineWidth: Double(lineWidth))
    )
    ZStack {
      Circle()
        .stroke(Color.white.opacity(0.16), lineWidth: lineWidth)
      Circle()
        .trim(from: CGFloat(trim?.from ?? 0), to: CGFloat(trim?.to ?? 0))
        .stroke(
          figures.isOver ? MealWidgetPalette.orange500 : Color.white,
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .scaleEffect(x: -1, y: 1)
      Circle()
        .fill(MealWidgetPalette.orange500)
        .frame(width: 13, height: 13)
        .offset(x: radius * CGFloat(cos(angle)), y: -radius * CGFloat(sin(angle)))
      VStack(spacing: 0) {
        Text(figures.headline)
          .font(MealWidgetFont.medium(12))
          .foregroundStyle(Color.white.opacity(0.75))
        Text(MealWidgetPalette.kcal(figures.headlineValue))
          .font(MealWidgetFont.bold(36))
          .tracking(-1.44)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .padding(.horizontal, 10)
        Text("kcal")
          .font(MealWidgetFont.bold(12))
          .foregroundStyle(Color.white.opacity(0.9))
      }
    }
    .frame(width: radius * 2, height: radius * 2)
  }
}

/// ホームのボタン1つ。ラベルはアプリでユーザーが変える（最大8文字）。
/// 5文字までは10ptで1行、6文字は1行のまま少し縮め、7文字以上は2行に折り返す。
private struct HomeTile: View {
  let label: String

  var body: some View {
    let singleLine = label.count <= 6
    VStack(spacing: 7) {
      Image(systemName: "plus")
        .font(.system(size: 12, weight: .heavy))
        .foregroundStyle(MealWidgetPalette.green800)
        .frame(width: 26, height: 26)
        .background(Color.white, in: Circle())
      Text(label)
        .font(MealWidgetFont.bold(10))
        .tracking(-0.4)
        .lineLimit(singleLine ? 1 : 2)
        .minimumScaleFactor(singleLine ? 0.8 : 0.9)
        .multilineTextAlignment(.center)
        // 1行でも2行でも「＋」の位置がそろうよう、ラベルは常に2行分の高さを取る
        .frame(height: 30)
    }
    .padding(.horizontal, 2)
    .frame(maxWidth: .infinity)
    .frame(height: 76)
    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    )
  }
}

// MARK: - ロック画面（accessoryRectangular）

/// iOS がロック画面を単色で描くため、色は使わない。
/// 白く塗ったボタンと大きな数字で、どの壁紙でも押す場所とカロリーがすぐ分かるようにする。
struct LockMealWidgetView: View {
  let entry: MealWidgetEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(entry.figures.shortHeadline)
          .font(MealWidgetFont.bold(12))
        Text(MealWidgetPalette.kcal(entry.figures.headlineValue))
          .font(MealWidgetFont.bold(31))
          .tracking(-1.24)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text("kcal")
          .font(MealWidgetFont.bold(12))
      }
      .padding(.leading, 2)
      .frame(height: 32, alignment: .bottomLeading)
      Spacer(minLength: 0)
      let buttons = Array(entry.buttons.prefix(3))
      let longest = buttons.map { $0.displayLabel.count }.max() ?? 0
      HStack(spacing: 5) {
        ForEach(buttons) { button in
          Button(intent: RegisterMealWidgetIntent(surface: "lock", slot: button.slot, kind: button.kind)) {
            LockCapsule(label: button.displayLabel, longest: longest)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .foregroundStyle(Color.white)
    .padding(EdgeInsets(top: 6, leading: 7, bottom: 7, trailing: 7))
    .containerBackground(for: .widget) {
      AccessoryWidgetBackground()
    }
  }
}

/// ロック画面のボタン1つ。白い面に黒い文字を置く（単色の描画では文字が抜けて見える）。
/// ラベルはアプリでユーザーが変える（最大8文字）。ボタンの幅は約45pt。
/// 3つのボタンの文字の大きさは、いちばん長いラベルに合わせてそろえる。
/// - 2文字まで: 「＋」付き15pt
/// - 3文字: 13pt
/// - 4文字以上: 10pt。5文字以上は入りきらない分を末尾で「…」と省く
private struct LockCapsule: View {
  let label: String
  let longest: Int

  var body: some View {
    Group {
      if longest <= 2 {
        HStack(spacing: 1) {
          Image(systemName: "plus")
            .font(.system(size: 11, weight: .heavy))
          Text(label)
            .font(MealWidgetFont.bold(15))
        }
      } else {
        Text(label)
          .font(MealWidgetFont.bold(longest == 3 ? 13 : 10))
      }
    }
    .lineLimit(1)
    .foregroundStyle(Color.black)
    .padding(.horizontal, 2)
    .frame(maxWidth: .infinity)
    .frame(height: 26)
    .background(Color.white, in: Capsule())
  }
}

/// ホームとロック画面のボタン。ショートカットや Siri には出さない。
/// 食事と運動の音声登録は、アプリ本体の別の App Intent。
struct RegisterMealWidgetIntent: AppIntent {
  static var title: LocalizedStringResource = "ウィジェットのパターンを登録"
  static var openAppWhenRun = false
  static var isDiscoverable = false

  @Parameter(title: "画面")
  var surface: String

  @Parameter(title: "ボタン")
  var slot: Int

  @Parameter(title: "種類")
  var kind: String

  init() {
    self.surface = "lock"
    self.slot = 0
    self.kind = ""
  }

  init(surface: String, slot: Int, kind: String = "") {
    self.surface = surface
    self.slot = slot
    self.kind = kind
  }

  func perform() async throws -> some IntentResult {
    let pattern = kind == "meal" || kind == "exercise" ? kind : nil
    _ = try WidgetAnalytics.recordPress(surface: surface, slot: slot, kind: pattern)
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
