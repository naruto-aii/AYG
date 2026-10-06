import 'dart:convert';

import '../data/met_activity_catalog.dart';
import '../models/exercise_calculation_source.dart';
import '../models/exercise_entry.dart';
import '../models/exercise_quantity_unit.dart';
import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/food_unit_type.dart';
import '../models/saved_food.dart';
import '../services/exercise_calorie_calculator.dart';
import '../utils/food_search_normalizer.dart';
import 'lock_screen_meal.dart';
import 'siri_name_match.dart';
import 'siri_speech_repair.dart';

/// Siri の食事・運動登録。
///
/// 決まった始まりは「Hey Siri、カロナビで」。食事か運動かは言葉から判別する。
/// 登録前に「鶏むね100gの食事でいいですね」のように復唱し、合っていれば作る。
/// 食品と運動とテンプレートは、アプリ内検索と同じ順位で名寄せする。
/// ひとつに決まればそれを採用し、同じ段が続けば上位数件を選ばせる。
/// 0件のときは言い直すか、検索語を残してアプリを開く。
/// 大盛りや「した」のように量が決まらないときは、g か分を聞き返す。
/// 食事テンプレートと運動テンプレートは、名前を言うとその内容で登録する。
/// 公開食品はここには含めない。
/// 「いいえ」と無言では作らない。アプリ名が無い文は登録しない。
/// 判定と書き込みはアプリを開かずに行い、アプリは次に開いたとき取り込む。
const String siriVoiceMethodChannel = 'com.narutoaii.ayg/siri_voice';

enum SiriAnswer { yes, no, silence }

enum SiriSpokenKind { meal, exercise }

enum SiriVoiceStatus {
  ready,
  unpaid,
  signedOut,
  notFound,
  ambiguous,
  needsChoice,
  needsAmount,
  rescue,
  needsKind,
  unsupportedAmount,
  missingWeight,
  declined,
  silence,
  registered,
}

enum SiriQuantityUnit {
  grams,
  milliliters,
  piece,
  serving,
  minutes,
  kilometers,
  reps,
}

class SiriQuantity {
  const SiriQuantity(this.amount, this.unit);

  final double amount;
  final SiriQuantityUnit unit;
}

class SiriFoodRecord {
  const SiriFoodRecord({
    required this.id,
    required this.speakName,
    required this.keys,
    required this.baseAmount,
    required this.unit,
    required this.source,
    this.kcalPerBase,
    this.proteinPerBase,
    this.fatPerBase,
    this.carbPerBase,
    this.savedFoodId,
    this.sourceOwnerUserId,
    this.version,
    this.officialFoodCode,
    this.officialFoodName,
    this.isCandidate = false,
    this.candidateRank = 100,
    this.priority = 100,
  });

  final String id;
  final String speakName;
  final List<String> keys;
  final double baseAmount;
  final FoodUnitType unit;
  final FoodEntrySource source;
  final double? kcalPerBase;
  final double? proteinPerBase;
  final double? fatPerBase;
  final double? carbPerBase;
  final String? savedFoodId;
  final String? sourceOwnerUserId;
  final int? version;
  final String? officialFoodCode;
  final String? officialFoodName;

  /// 同じ呼び方が複数の食品にあるときの候補。確定した別名は false。
  final bool isCandidate;
  final int candidateRank;
  final int priority;

  factory SiriFoodRecord.saved(SavedFood food) {
    return SiriFoodRecord(
      id: food.foodId,
      speakName: food.name,
      keys: _keys([food.normalizedName, food.name, food.officialFoodName]),
      baseAmount: food.baseAmount,
      unit: food.unitType,
      source: FoodEntrySource.savedFood,
      kcalPerBase: food.kcalPerBase,
      proteinPerBase: food.proteinPerBase,
      fatPerBase: food.fatPerBase,
      carbPerBase: food.carbPerBase,
      savedFoodId: food.foodId,
      sourceOwnerUserId: food.ownerUserId,
      version: food.version,
      officialFoodCode: food.officialFoodCode,
      officialFoodName: food.officialFoodName,
    );
  }

  factory SiriFoodRecord.official({
    required String foodCode,
    required String name,
    required String speakName,
    required List<String> matchTexts,
    required double baseAmount,
    required FoodUnitType unit,
    double? kcalPerBase,
    double? proteinPerBase,
    double? fatPerBase,
    double? carbPerBase,
    bool isCandidate = false,
    int candidateRank = 100,
    int priority = 100,
  }) {
    return SiriFoodRecord(
      id: foodCode,
      speakName: speakName,
      keys: _keys(matchTexts),
      baseAmount: baseAmount <= 0 ? 100 : baseAmount,
      unit: unit,
      source: FoodEntrySource.mextSfct,
      kcalPerBase: kcalPerBase,
      proteinPerBase: proteinPerBase,
      fatPerBase: fatPerBase,
      carbPerBase: carbPerBase,
      officialFoodCode: foodCode,
      officialFoodName: name,
      isCandidate: isCandidate,
      candidateRank: candidateRank,
      priority: priority,
    );
  }
}

class SiriTemplateFood {
  const SiriTemplateFood({required this.food, required this.consumedAmount});

  final SiriFoodRecord food;
  final double consumedAmount;
}

class SiriMealTemplate {
  const SiriMealTemplate({
    required this.id,
    required this.speakName,
    required this.keys,
    required this.items,
  });

  final String id;
  final String speakName;
  final List<String> keys;
  final List<SiriTemplateFood> items;
}

class SiriWorkoutTemplateExercise {
  const SiriWorkoutTemplateExercise({
    required this.activityId,
    this.minutes,
    this.kilometers,
  });

  final String activityId;
  final double? minutes;
  final double? kilometers;
}

class SiriWorkoutTemplate {
  const SiriWorkoutTemplate({
    required this.id,
    required this.speakName,
    required this.keys,
    required this.exercises,
  });

  final String id;
  final String speakName;
  final List<String> keys;
  final List<SiriWorkoutTemplateExercise> exercises;
}

class SiriSpokenChoice {
  const SiriSpokenChoice({
    required this.id,
    required this.title,
    required this.kind,
  });

  final String id;

  /// `food` / `exercise` / `mealTemplate` / `workoutTemplate`
  final String kind;
  final String title;
}

class SiriVoiceContext {
  const SiriVoiceContext({
    required this.paid,
    required this.ownerUserId,
    required this.foods,
    this.weightKg,
    this.mealTemplates = const [],
    this.workoutTemplates = const [],
  });

  final bool paid;
  final String ownerUserId;
  final double? weightKg;
  final List<SiriFoodRecord> foods;
  final List<SiriMealTemplate> mealTemplates;
  final List<SiriWorkoutTemplate> workoutTemplates;
}

class SiriVoicePlan {
  const SiriVoicePlan._({
    required this.status,
    required this.spoken,
    required this.asksConfirmation,
    this.asksKind = false,
    this.food,
    this.activityId,
    this.quantity,
    this.spokenName,
    this.asksChoice = false,
    this.choices = const [],
    this.asksAmount = false,
    this.asksRetry = false,
    this.searchQuery,
    this.mealTemplate,
    this.workoutTemplate,
    this.pendingQuantityText,
  });

  final SiriVoiceStatus status;
  final String spoken;
  final bool asksConfirmation;

  /// 復唱が食事か運動かの質問。はいでは登録しない。
  final bool asksKind;
  final SiriFoodRecord? food;
  final String? activityId;
  final SiriQuantity? quantity;
  final String? spokenName;
  final bool asksChoice;
  final List<SiriSpokenChoice> choices;
  final bool asksAmount;
  final bool asksRetry;
  final String? searchQuery;
  final SiriMealTemplate? mealTemplate;
  final SiriWorkoutTemplate? workoutTemplate;
  final String? pendingQuantityText;

  bool get isReady =>
      status == SiriVoiceStatus.ready &&
      asksConfirmation &&
      !asksKind &&
      !asksChoice &&
      !asksAmount;
}

class SiriVoiceResult {
  const SiriVoiceResult({
    required this.status,
    required this.spoken,
    this.food,
    this.exercise,
    this.foods = const [],
    this.exercises = const [],
  });

  final SiriVoiceStatus status;
  final String spoken;
  final FoodEntry? food;
  final ExerciseEntry? exercise;
  final List<FoodEntry> foods;
  final List<ExerciseEntry> exercises;

  bool get registered =>
      status == SiriVoiceStatus.registered &&
      (food != null ||
          exercise != null ||
          foods.isNotEmpty ||
          exercises.isNotEmpty);
}

class SiriOpenSearch {
  const SiriOpenSearch({required this.kind, required this.query});

  /// `food` または `exercise`。
  final String kind;
  final String query;

  static SiriOpenSearch? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }
    final query = decoded['query'];
    final kind = decoded['kind'];
    if (query is! String || query.trim().isEmpty) {
      return null;
    }
    return SiriOpenSearch(
      kind: kind == 'exercise' ? 'exercise' : 'food',
      query: query.trim(),
    );
  }
}

class SiriVoiceImportPlan {
  const SiriVoiceImportPlan({
    required this.foods,
    required this.exercises,
    required this.acknowledgeIds,
  });

  final List<FoodEntry> foods;
  final List<ExerciseEntry> exercises;
  final List<String> acknowledgeIds;
}

SiriQuantity? parseSiriQuantity(String raw) {
  final compact = raw
      .trim()
      .replaceAll(' ', '')
      .replaceAll('　', '')
      .replaceFirst(RegExp(r'[。．.！!？?]+$'), '');
  final match = RegExp(r'^(\d+(?:\.\d+)?)(.*)$').firstMatch(compact);
  if (match == null) {
    return null;
  }
  final amount = double.tryParse(match.group(1)!);
  if (amount == null || amount <= 0 || amount >= 100000) {
    return null;
  }
  final unit = switch (match.group(2)) {
    'g' || 'G' || 'ｇ' || 'グラム' => SiriQuantityUnit.grams,
    'ml' || 'mL' || 'ML' || 'ｍｌ' || 'ミリリットル' => SiriQuantityUnit.milliliters,
    '個' || 'こ' || 'コ' => SiriQuantityUnit.piece,
    '食' || '食分' => SiriQuantityUnit.serving,
    '分' || '分間' => SiriQuantityUnit.minutes,
    '回' => SiriQuantityUnit.reps,
    'km' || 'KM' || '㎞' || 'キロ' || 'キロメートル' => SiriQuantityUnit.kilometers,
    _ => null,
  };
  if (unit == null) {
    return null;
  }
  return SiriQuantity(amount, unit);
}

String formatSiriQuantity(SiriQuantity quantity) {
  final amount = quantity.amount;
  final number = amount == amount.roundToDouble()
      ? '${amount.round()}'
      : amount.toString();
  final suffix = switch (quantity.unit) {
    SiriQuantityUnit.grams => 'g',
    SiriQuantityUnit.milliliters => 'ml',
    SiriQuantityUnit.piece => '個',
    SiriQuantityUnit.serving => '食',
    SiriQuantityUnit.minutes => '分',
    SiriQuantityUnit.kilometers => 'km',
    SiriQuantityUnit.reps => '回',
  };
  return '$number$suffix';
}

SiriVoicePlan planSiriFood({
  required SiriVoiceContext context,
  required String name,
  required String quantity,
}) {
  return _plan(
    context: context,
    name: name,
    quantity: quantity,
    forced: SiriSpokenKind.meal,
  );
}

SiriVoicePlan planSiriExercise({
  required SiriVoiceContext context,
  required String name,
  required String quantity,
}) {
  return _plan(
    context: context,
    name: name,
    quantity: quantity,
    forced: SiriSpokenKind.exercise,
  );
}

/// 「カロナビで」のあとの文。食事か運動かはここで判別する。
SiriVoicePlan planSiriUtterance({
  required SiriVoiceContext context,
  required String name,
  required String quantity,
}) {
  return _plan(context: context, name: name, quantity: quantity, forced: null);
}

/// 食事か運動かの復唱に答えたあと、その種類で中身を確認する。
SiriVoicePlan resolveSiriSpokenKind({
  required SiriVoiceContext context,
  required SiriVoicePlan plan,
  required SiriSpokenKind kind,
}) {
  final spokenName = plan.spokenName;
  final quantity = plan.quantity;
  if (!plan.asksKind || spokenName == null || quantity == null) {
    return plan;
  }
  final quantityText = formatSiriQuantity(quantity);
  if (kind == SiriSpokenKind.meal) {
    return _planFoodBody(
      context,
      name: spokenName,
      quantityText: quantityText,
    );
  }
  return _planExerciseBody(
    context,
    name: spokenName,
    quantityText: quantityText,
  );
}

/// 候補を選んだあと、量があれば復唱まで進める。
SiriVoicePlan resolveSiriChoice({
  required SiriVoiceContext context,
  required SiriVoicePlan plan,
  required String choiceId,
}) {
  if (!plan.asksChoice) {
    return plan;
  }
  SiriSpokenChoice? choice;
  for (final item in plan.choices) {
    if (item.id == choiceId) {
      choice = item;
      break;
    }
  }
  if (choice == null) {
    return plan;
  }
  final quantityText = plan.pendingQuantityText ?? '';
  return switch (choice.kind) {
    'mealTemplate' => _confirmMealTemplate(
      context,
      id: choice.id,
      quantityText: quantityText,
    ),
    'workoutTemplate' => _confirmWorkoutTemplate(context, id: choice.id),
    'exercise' => _confirmExercise(
      context,
      activityId: choice.id,
      quantityText: quantityText,
      spokenName: choice.title,
    ),
    _ => _confirmFood(
      context,
      foodId: choice.id,
      quantityText: quantityText,
    ),
  };
}

/// 「何gですか？」「何分ですか？」への答え。
SiriVoicePlan resolveSiriAmount({
  required SiriVoiceContext context,
  required SiriVoicePlan plan,
  required String amountText,
}) {
  if (!plan.asksAmount) {
    return plan;
  }
  final mealTemplate = plan.mealTemplate;
  if (mealTemplate != null) {
    return _readyMealTemplate(mealTemplate);
  }
  final food = plan.food;
  if (food != null) {
    return _confirmFood(
      context,
      foodId: food.id,
      quantityText: amountText,
      assumeFoodUnit: true,
    );
  }
  final activityId = plan.activityId;
  if (activityId != null) {
    return _confirmExercise(
      context,
      activityId: activityId,
      quantityText: amountText,
      spokenName: plan.spokenName ?? '',
      assumeMinutes: true,
    );
  }
  return plan;
}

SiriVoicePlan? _chooseInterpretation(
  SiriVoiceContext context,
  List<String> interpretations,
  SiriSpokenKind? kind,
) {
  final scored = <_SpeechScore>[];
  for (final text in interpretations) {
    final split = _split(text, '');
    final hit = _bestSpeechHit(context, split.name, kind);
    scored.add(
      _SpeechScore(
        name: split.name,
        quantity: split.quantity,
        rank: hit?.rank ?? 9,
        id: hit?.id,
        title: hit?.title,
        choiceKind: hit?.choiceKind,
      ),
    );
  }
  scored.sort((a, b) => a.rank.compareTo(b.rank));
  final best = scored.first.rank;
  if (best >= 9) {
    return null;
  }
  final winners = scored.where((item) => item.rank == best).toList();
  final ids = winners.map((item) => item.id).toSet();
  if (ids.length == 1) {
    final winner = winners.first;
    if (kind == SiriSpokenKind.meal) {
      return _planFoodBody(
        context,
        name: winner.name,
        quantityText: winner.quantity,
      );
    }
    if (kind == SiriSpokenKind.exercise) {
      return _planExerciseBody(
        context,
        name: winner.name,
        quantityText: winner.quantity,
      );
    }
    return _classify(
      context,
      name: winner.name,
      quantityText: winner.quantity,
    );
  }
  return _choicePlan(
    name: winners.first.name,
    quantityText: winners.first.quantity,
    choices: [
      for (final winner in winners)
        if (winner.id != null &&
            winner.title != null &&
            winner.choiceKind != null)
          SiriSpokenChoice(
            id: winner.id!,
            title: winner.title!,
            kind: winner.choiceKind!,
          ),
    ],
  );
}

_SpeechHit? _bestSpeechHit(
  SiriVoiceContext context,
  String name,
  SiriSpokenKind? kind,
) {
  final hits = <_SpeechHit>[];
  void add(SiriMatchResult result, String choiceKind, {String suffix = ''}) {
    if (result.hits.isEmpty) {
      return;
    }
    final top = result.hits.first;
    hits.add(
      _SpeechHit(
        rank: top.matchRank,
        id: top.id,
        title: '${top.speakName}$suffix',
        choiceKind: choiceKind,
      ),
    );
  }

  if (kind != SiriSpokenKind.exercise) {
    add(_rankFoods(context, name), 'food');
    add(
      _rankTemplates(
        context.mealTemplates.map(
          (template) => (
            id: template.id,
            speakName: template.speakName,
            keys: template.keys,
          ),
        ),
        name,
      ),
      'mealTemplate',
      suffix: '（テンプレート）',
    );
  }
  if (kind != SiriSpokenKind.meal) {
    add(_rankExercises(name), 'exercise');
    add(
      _rankTemplates(
        context.workoutTemplates.map(
          (template) => (
            id: template.id,
            speakName: template.speakName,
            keys: template.keys,
          ),
        ),
        name,
      ),
      'workoutTemplate',
      suffix: '（テンプレート）',
    );
  }
  if (hits.isEmpty) {
    return null;
  }
  hits.sort((a, b) => a.rank.compareTo(b.rank));
  return hits.first;
}

class _SpeechScore {
  const _SpeechScore({
    required this.name,
    required this.quantity,
    required this.rank,
    required this.id,
    required this.title,
    required this.choiceKind,
  });

  final String name;
  final String quantity;
  final int rank;
  final String? id;
  final String? title;
  final String? choiceKind;
}

class _SpeechHit {
  const _SpeechHit({
    required this.rank,
    required this.id,
    required this.title,
    required this.choiceKind,
  });

  final int rank;
  final String id;
  final String title;
  final String choiceKind;
}

SiriVoicePlan _plan({
  required SiriVoiceContext context,
  required String name,
  required String quantity,
  required SiriSpokenKind? forced,
}) {
  final blocked = _blocked(context);
  if (blocked != null) {
    return blocked;
  }
  final source = _utterance(name, quantity);
  if (_mentionsPhraseShape(source) && !source.contains('カロナビ')) {
    return _stop(SiriVoiceStatus.unsupportedAmount, 'アプリ名が無いので登録しません');
  }
  final explicit = _explicitSpokenKind(source);
  final kind = explicit ?? (_mentionsPhraseShape(source) ? null : forced);
  final spoken = quantity.trim().isEmpty
      ? name
      : '${name.trim()} ${quantity.trim()}';
  final interpretations = <String>[];
  for (final option in siriSpeechInterpretations(spoken)) {
    final folded = foldSiriSpokenQuantities(option);
    if (folded.isNotEmpty && !interpretations.contains(folded)) {
      interpretations.add(folded);
    }
  }
  if (interpretations.length > 1) {
    final chosen = _chooseInterpretation(
      context,
      interpretations,
      kind,
    );
    if (chosen != null) {
      return chosen;
    }
  }
  final repaired = interpretations.isEmpty ? spoken : interpretations.first;
  final split = _split(repaired, interpretations.isEmpty ? quantity : '');
  if (kind == SiriSpokenKind.meal) {
    return _planFoodBody(
      context,
      name: split.name,
      quantityText: split.quantity,
    );
  }
  if (kind == SiriSpokenKind.exercise) {
    return _planExerciseBody(
      context,
      name: split.name,
      quantityText: split.quantity,
    );
  }
  return _classify(context, name: split.name, quantityText: split.quantity);
}

SiriVoicePlan _classify(
  SiriVoiceContext context, {
  required String name,
  required String quantityText,
}) {
  if (name.isEmpty) {
    return _stop(SiriVoiceStatus.notFound, '内容が分かりません');
  }
  final parsed = parseSiriQuantity(quantityText);
  final foodNamed = _namesFood(context, name);
  final exerciseNamed = _namesExercise(context, name);
  if (foodNamed && !exerciseNamed) {
    return _planFoodBody(context, name: name, quantityText: quantityText);
  }
  if (exerciseNamed && !foodNamed) {
    return _planExerciseBody(context, name: name, quantityText: quantityText);
  }
  if (parsed == null) {
    if (!foodNamed && !exerciseNamed) {
      return _rescue(name, meal: true);
    }
    return _stop(SiriVoiceStatus.unsupportedAmount, '量が分かりません');
  }
  return SiriVoicePlan._(
    status: SiriVoiceStatus.needsKind,
    spoken: '$name${formatSiriQuantity(parsed)}は、食事ですか、運動ですか',
    asksConfirmation: true,
    asksKind: true,
    quantity: parsed,
    spokenName: name,
    pendingQuantityText: quantityText,
  );
}

SiriVoicePlan _planFoodBody(
  SiriVoiceContext context, {
  required String name,
  required String quantityText,
}) {
  if (name.isEmpty) {
    return _stop(SiriVoiceStatus.notFound, '食品名が分かりません');
  }
  final templates = _rankTemplates(
    context.mealTemplates.map(
      (template) => (id: template.id, speakName: template.speakName, keys: template.keys),
    ),
    name,
  );
  final foods = _rankFoods(context, name);
  final templateExact =
      templates.decision == SiriMatchDecision.one &&
      templates.hits.single.matchRank == 0;
  final foodExact =
      foods.decision == SiriMatchDecision.one && foods.hits.single.matchRank == 0;
  if (templateExact && foodExact) {
    return _choicePlan(
      name: name,
      quantityText: quantityText,
      choices: [
        SiriSpokenChoice(
          id: templates.hits.single.id,
          title: '${templates.hits.single.speakName}（テンプレート）',
          kind: 'mealTemplate',
        ),
        SiriSpokenChoice(
          id: foods.hits.single.id,
          title: foods.hits.single.speakName,
          kind: 'food',
        ),
      ],
    );
  }
  if (templateExact) {
    return _confirmMealTemplate(
      context,
      id: templates.hits.single.id,
      quantityText: quantityText,
    );
  }
  if (foods.decision == SiriMatchDecision.none &&
      templates.decision == SiriMatchDecision.none) {
    return _rescue(name, meal: true);
  }
  if (foods.decision == SiriMatchDecision.choices) {
    return _choicePlan(
      name: name,
      quantityText: quantityText,
      choices: [
        for (final hit in foods.hits)
          SiriSpokenChoice(id: hit.id, title: hit.speakName, kind: 'food'),
      ],
    );
  }
  if (foods.decision == SiriMatchDecision.none &&
      templates.decision == SiriMatchDecision.choices) {
    return _choicePlan(
      name: name,
      quantityText: quantityText,
      choices: [
        for (final hit in templates.hits)
          SiriSpokenChoice(
            id: hit.id,
            title: '${hit.speakName}（テンプレート）',
            kind: 'mealTemplate',
          ),
      ],
    );
  }
  if (foods.decision == SiriMatchDecision.none &&
      templates.decision == SiriMatchDecision.one) {
    return _confirmMealTemplate(
      context,
      id: templates.hits.single.id,
      quantityText: quantityText,
    );
  }
  return _confirmFood(
    context,
    foodId: foods.hits.single.id,
    quantityText: quantityText,
  );
}

SiriVoicePlan _planExerciseBody(
  SiriVoiceContext context, {
  required String name,
  required String quantityText,
}) {
  if (name.isEmpty) {
    return _stop(SiriVoiceStatus.notFound, '種目が分かりません');
  }
  final templates = _rankTemplates(
    context.workoutTemplates.map(
      (template) => (id: template.id, speakName: template.speakName, keys: template.keys),
    ),
    name,
  );
  final activities = _rankExercises(name);
  final templateExact =
      templates.decision == SiriMatchDecision.one &&
      templates.hits.single.matchRank == 0;
  final activityExact =
      activities.decision == SiriMatchDecision.one &&
      activities.hits.single.matchRank == 0;
  if (templateExact && activityExact) {
    return _choicePlan(
      name: name,
      quantityText: quantityText,
      choices: [
        SiriSpokenChoice(
          id: templates.hits.single.id,
          title: '${templates.hits.single.speakName}（テンプレート）',
          kind: 'workoutTemplate',
        ),
        SiriSpokenChoice(
          id: activities.hits.single.id,
          title: activities.hits.single.speakName,
          kind: 'exercise',
        ),
      ],
    );
  }
  if (templateExact) {
    return _confirmWorkoutTemplate(context, id: templates.hits.single.id);
  }
  if (activities.decision == SiriMatchDecision.none &&
      templates.decision == SiriMatchDecision.none) {
    return _rescue(name, meal: false);
  }
  if (activities.decision == SiriMatchDecision.choices) {
    return _choicePlan(
      name: name,
      quantityText: quantityText,
      choices: [
        for (final hit in activities.hits)
          SiriSpokenChoice(id: hit.id, title: hit.speakName, kind: 'exercise'),
      ],
    );
  }
  if (activities.decision == SiriMatchDecision.none &&
      templates.decision == SiriMatchDecision.one) {
    return _confirmWorkoutTemplate(context, id: templates.hits.single.id);
  }
  if (activities.decision == SiriMatchDecision.none) {
    return _choicePlan(
      name: name,
      quantityText: quantityText,
      choices: [
        for (final hit in templates.hits)
          SiriSpokenChoice(
            id: hit.id,
            title: '${hit.speakName}（テンプレート）',
            kind: 'workoutTemplate',
          ),
      ],
    );
  }
  return _confirmExercise(
    context,
    activityId: activities.hits.single.id,
    quantityText: quantityText,
    spokenName: activities.hits.single.speakName,
  );
}

SiriVoicePlan _confirmFood(
  SiriVoiceContext context, {
  required String foodId,
  required String quantityText,
  bool assumeFoodUnit = false,
}) {
  SiriFoodRecord? food;
  for (final item in context.foods) {
    if (item.id == foodId) {
      food = item;
      break;
    }
  }
  if (food == null) {
    return _rescue(quantityText, meal: true);
  }
  final parsed = _parseFoodAmount(
    quantityText,
    unit: food.unit,
    assumeUnit: assumeFoodUnit,
  );
  if (parsed == null) {
    return SiriVoicePlan._(
      status: SiriVoiceStatus.needsAmount,
      spoken: _foodAmountQuestion(food.unit),
      asksConfirmation: false,
      asksAmount: true,
      food: food,
      spokenName: food.speakName,
      pendingQuantityText: quantityText,
    );
  }
  if (!_foodUnitFits(food.unit, parsed.unit)) {
    return _stop(
      SiriVoiceStatus.unsupportedAmount,
      '${food.speakName}は${food.unit.label}で指定してください',
    );
  }
  final amount = formatSiriQuantity(parsed);
  return SiriVoicePlan._(
    status: SiriVoiceStatus.ready,
    spoken: '${food.speakName}$amountの食事でいいですね',
    asksConfirmation: true,
    food: food,
    quantity: parsed,
    spokenName: food.speakName,
  );
}

SiriVoicePlan _confirmMealTemplate(
  SiriVoiceContext context, {
  required String id,
  required String quantityText,
}) {
  SiriMealTemplate? template;
  for (final item in context.mealTemplates) {
    if (item.id == id) {
      template = item;
      break;
    }
  }
  if (template == null || template.items.isEmpty) {
    return _stop(SiriVoiceStatus.notFound, 'テンプレートの中身がありません');
  }
  return _readyMealTemplate(template);
}

SiriVoicePlan _readyMealTemplate(SiriMealTemplate template) {
  return SiriVoicePlan._(
    status: SiriVoiceStatus.ready,
    spoken: '${template.speakName}のテンプレートでいいですね',
    asksConfirmation: true,
    mealTemplate: template,
    spokenName: template.speakName,
  );
}

SiriVoicePlan _confirmExercise(
  SiriVoiceContext context, {
  required String activityId,
  required String quantityText,
  required String spokenName,
  bool assumeMinutes = false,
}) {
  final activity = MetActivityCatalog.findById(activityId);
  if (activity == null || !activity.searchable) {
    return _rescue(spokenName, meal: false);
  }
  if (activity.requiresManualKcal ||
      activity.quantityUnit == ExerciseQuantityUnit.reps) {
    return _stop(
      SiriVoiceStatus.unsupportedAmount,
      '${activity.displayName}は手入力の種目です',
    );
  }
  final parsed = _parseExerciseAmount(quantityText, assumeMinutes: assumeMinutes);
  if (parsed == null) {
    return SiriVoicePlan._(
      status: SiriVoiceStatus.needsAmount,
      spoken: '何分ですか？',
      asksConfirmation: false,
      asksAmount: true,
      activityId: activity.id,
      spokenName: activity.displayName,
      pendingQuantityText: quantityText,
    );
  }
  final spokenUnitFits = _exerciseUnitFits(activity, parsed.unit);
  if (!spokenUnitFits) {
    final unitLabel = switch (activity.quantityUnit) {
      ExerciseQuantityUnit.distanceKm =>
        parsed.unit == SiriQuantityUnit.minutes ? 'km' : 'kmか分',
      ExerciseQuantityUnit.durationMin => '分',
      ExerciseQuantityUnit.reps => '回',
    };
    return _stop(
      SiriVoiceStatus.unsupportedAmount,
      '${activity.displayName}は$unitLabelで指定してください',
    );
  }
  final needsWeight = !activity.lifestyleIncluded;
  final weight = context.weightKg;
  if (needsWeight && (weight == null || weight <= 0)) {
    return _stop(SiriVoiceStatus.missingWeight, '体重が無いので登録できません');
  }
  final built = buildSiriExerciseEntry(
    id: 'check',
    activityId: activity.id,
    amount: parsed.amount,
    unit: parsed.unit,
    weightKg: weight,
    loggedAt: DateTime(2026),
  );
  if (built == null) {
    return _stop(SiriVoiceStatus.unsupportedAmount, '計算できないので登録しません');
  }
  final amount = formatSiriQuantity(parsed);
  return SiriVoicePlan._(
    status: SiriVoiceStatus.ready,
    spoken: '${activity.displayName}$amountの運動でいいですね',
    asksConfirmation: true,
    activityId: activity.id,
    quantity: parsed,
    spokenName: activity.displayName,
  );
}

SiriVoicePlan _confirmWorkoutTemplate(
  SiriVoiceContext context, {
  required String id,
}) {
  SiriWorkoutTemplate? template;
  for (final item in context.workoutTemplates) {
    if (item.id == id) {
      template = item;
      break;
    }
  }
  if (template == null || template.exercises.isEmpty) {
    return _stop(SiriVoiceStatus.notFound, 'テンプレートの中身がありません');
  }
  final weight = context.weightKg;
  for (final item in template.exercises) {
    final activity = MetActivityCatalog.findById(item.activityId);
    if (activity == null) {
      continue;
    }
    if (!activity.lifestyleIncluded && (weight == null || weight <= 0)) {
      return _stop(SiriVoiceStatus.missingWeight, '体重が無いので登録できません');
    }
  }
  return SiriVoicePlan._(
    status: SiriVoiceStatus.ready,
    spoken: '${template.speakName}のテンプレートでいいですね',
    asksConfirmation: true,
    workoutTemplate: template,
    spokenName: template.speakName,
  );
}

SiriVoicePlan _choicePlan({
  required String name,
  required String quantityText,
  required List<SiriSpokenChoice> choices,
}) {
  final titles = choices.map((choice) => choice.title).join('、');
  return SiriVoicePlan._(
    status: SiriVoiceStatus.needsChoice,
    spoken: '$nameは次のどれですか。$titles',
    asksConfirmation: false,
    asksChoice: true,
    choices: choices,
    pendingQuantityText: quantityText,
    spokenName: name,
  );
}

SiriVoicePlan _rescue(String name, {required bool meal}) {
  final label = name.trim().isEmpty ? 'それ' : name.trim();
  return SiriVoicePlan._(
    status: SiriVoiceStatus.rescue,
    spoken: '$labelは見つかりません。もう一度言うか、アプリで検索します',
    asksConfirmation: false,
    asksRetry: true,
    searchQuery: label,
    spokenName: label,
  );
}

bool _namesFood(SiriVoiceContext context, String name) {
  if (_rankFoods(context, name).decision != SiriMatchDecision.none) {
    return true;
  }
  return _rankTemplates(
        context.mealTemplates.map(
          (template) => (
            id: template.id,
            speakName: template.speakName,
            keys: template.keys,
          ),
        ),
        name,
      ).decision !=
      SiriMatchDecision.none;
}

bool _namesExercise(SiriVoiceContext context, String name) {
  if (spokenExerciseActivityId(name) != null) {
    return true;
  }
  if (_rankExercises(name).decision != SiriMatchDecision.none) {
    return true;
  }
  return _rankTemplates(
        context.workoutTemplates.map(
          (template) => (
            id: template.id,
            speakName: template.speakName,
            keys: template.keys,
          ),
        ),
        name,
      ).decision !=
      SiriMatchDecision.none;
}

SiriMatchResult _rankFoods(SiriVoiceContext context, String name) {
  final saved = context.foods
      .where((food) => food.source == FoodEntrySource.savedFood)
      .toList();
  final savedHits = _foodHits(saved, name);
  if (savedHits.isNotEmpty) {
    return pickSiriMatches(savedHits);
  }
  return pickSiriMatches(
    _foodHits(
      context.foods
          .where((food) => food.source == FoodEntrySource.mextSfct)
          .toList(),
      name,
    ),
  );
}

List<SiriMatchHit> _foodHits(List<SiriFoodRecord> foods, String name) {
  final hits = <SiriMatchHit>[];
  for (final food in foods) {
    final rank = _bestKeyRank(food.keys, name);
    if (rank >= 9) {
      continue;
    }
    hits.add(
      SiriMatchHit(
        id: food.id,
        speakName: _foodSpeakLabel(food, foods),
        matchRank: rank,
        isCandidate: food.isCandidate,
        candidateRank: food.candidateRank,
        priority: food.priority,
        aliasMatched: rank == 0,
      ),
    );
  }
  return hits;
}

String _foodSpeakLabel(SiriFoodRecord food, List<SiriFoodRecord> peers) {
  final same = peers.where((item) => item.speakName == food.speakName).length;
  if (same < 2) {
    return food.speakName;
  }
  final official = food.officialFoodName;
  if (official != null && official.isNotEmpty && official != food.speakName) {
    return official;
  }
  return food.speakName;
}

SiriMatchResult _rankExercises(String name) {
  final spokenId = spokenExerciseActivityId(name);
  if (spokenId != null) {
    final activity = MetActivityCatalog.findById(spokenId);
    if (activity != null && activity.searchable) {
      return SiriMatchResult(SiriMatchDecision.one, [
        SiriMatchHit(
          id: activity.id,
          speakName: activity.displayName,
          matchRank: 0,
          aliasMatched: true,
        ),
      ]);
    }
  }
  final hits = <SiriMatchHit>[];
  for (final activity in MetActivityCatalog.activities) {
    if (!activity.searchable) {
      continue;
    }
    final rank = _bestKeyRank(
      [for (final alias in activity.aliases) FoodSearchNormalizer.normalize(alias)],
      name,
    );
    if (rank >= 9) {
      continue;
    }
    hits.add(
      SiriMatchHit(
        id: activity.id,
        speakName: activity.displayName,
        matchRank: rank,
        aliasMatched: rank == 0,
      ),
    );
  }
  return pickSiriMatches(hits);
}

SiriMatchResult _rankTemplates(
  Iterable<({String id, String speakName, List<String> keys})> templates,
  String name,
) {
  final hits = <SiriMatchHit>[];
  for (final template in templates) {
    final rank = _bestKeyRank(template.keys, name);
    if (rank >= 9) {
      continue;
    }
    hits.add(
      SiriMatchHit(
        id: template.id,
        speakName: template.speakName,
        matchRank: rank,
        aliasMatched: rank == 0,
      ),
    );
  }
  return pickSiriMatches(hits);
}

int _bestKeyRank(List<String> keys, String name) {
  var best = 9;
  for (final variant in siriQueryVariants(name)) {
    for (final key in keys) {
      final rank = siriTextRank(key, variant);
      if (rank < best) {
        best = rank;
      }
    }
  }
  return best;
}

SiriQuantity? _parseFoodAmount(
  String quantityText, {
  required FoodUnitType unit,
  required bool assumeUnit,
}) {
  final parsed = parseSiriQuantity(quantityText);
  if (parsed != null || !assumeUnit) {
    return parsed;
  }
  final suffix = switch (unit) {
    FoodUnitType.g => 'g',
    FoodUnitType.ml => 'ml',
    FoodUnitType.piece => '個',
    FoodUnitType.serving => '食',
  };
  return parseSiriQuantity('$quantityText$suffix');
}

SiriQuantity? _parseExerciseAmount(
  String quantityText, {
  required bool assumeMinutes,
}) {
  final parsed = parseSiriQuantity(quantityText);
  if (parsed != null || !assumeMinutes) {
    return parsed;
  }
  return parseSiriQuantity('${quantityText}分');
}

bool _exerciseUnitFits(MetActivityDefinition activity, SiriQuantityUnit spoken) {
  return switch (activity.quantityUnit) {
    ExerciseQuantityUnit.durationMin => spoken == SiriQuantityUnit.minutes,
    ExerciseQuantityUnit.distanceKm =>
      spoken == SiriQuantityUnit.kilometers ||
          spoken == SiriQuantityUnit.minutes,
    ExerciseQuantityUnit.reps => false,
  };
}

String _foodAmountQuestion(FoodUnitType unit) {
  return switch (unit) {
    FoodUnitType.g => '何gですか？',
    FoodUnitType.ml => '何mlですか？',
    FoodUnitType.piece => '何個ですか？',
    FoodUnitType.serving => '何食分ですか？',
  };
}

SiriVoiceResult commitSiriVoice({
  required SiriVoicePlan plan,
  required SiriAnswer answer,
  required DateTime loggedAt,
  required String ownerUserId,
  required double? weightKg,
  required String Function() newId,
}) {
  if (!plan.isReady) {
    return SiriVoiceResult(status: plan.status, spoken: plan.spoken);
  }
  if (answer == SiriAnswer.no) {
    return const SiriVoiceResult(
      status: SiriVoiceStatus.declined,
      spoken: '登録しません',
    );
  }
  if (answer != SiriAnswer.yes) {
    return const SiriVoiceResult(
      status: SiriVoiceStatus.silence,
      spoken: '登録しません',
    );
  }
  final mealTemplate = plan.mealTemplate;
  if (mealTemplate != null) {
    final foods = <FoodEntry>[];
    for (final item in mealTemplate.items) {
      final food = item.food;
      foods.add(
        FoodEntry(
          id: newId(),
          name: food.speakName,
          kcalPerBase: food.kcalPerBase,
          proteinPerBase: food.proteinPerBase,
          fatPerBase: food.fatPerBase,
          carbPerBase: food.carbPerBase,
          baseAmount: food.baseAmount,
          unitType: food.unit,
          consumedAmount: item.consumedAmount,
          sourceType: food.source,
          savedFoodId: food.savedFoodId,
          sourceFoodOwnerUserId: food.sourceOwnerUserId,
          sourceSavedFoodVersion: food.version,
          officialFoodCode: food.officialFoodCode,
          officialFoodName: food.officialFoodName,
          loggedAt: loggedAt,
        ),
      );
    }
    if (foods.isEmpty) {
      return const SiriVoiceResult(
        status: SiriVoiceStatus.unsupportedAmount,
        spoken: '登録しません',
      );
    }
    return SiriVoiceResult(
      status: SiriVoiceStatus.registered,
      spoken: '登録しました',
      food: foods.length == 1 ? foods.single : null,
      foods: foods,
    );
  }
  final workoutTemplate = plan.workoutTemplate;
  if (workoutTemplate != null) {
    final exercises = <ExerciseEntry>[];
    for (final item in workoutTemplate.exercises) {
      final kilometers = item.kilometers;
      final minutes = item.minutes;
      final unit = kilometers != null && kilometers > 0
          ? SiriQuantityUnit.kilometers
          : SiriQuantityUnit.minutes;
      final amount = kilometers != null && kilometers > 0
          ? kilometers
          : (minutes ?? 0);
      if (amount <= 0) {
        continue;
      }
      final exercise = buildSiriExerciseEntry(
        id: newId(),
        activityId: item.activityId,
        amount: amount,
        unit: unit,
        weightKg: weightKg,
        loggedAt: loggedAt,
      );
      if (exercise != null) {
        exercises.add(exercise);
      }
    }
    if (exercises.isEmpty) {
      return const SiriVoiceResult(
        status: SiriVoiceStatus.unsupportedAmount,
        spoken: '登録しません',
      );
    }
    return SiriVoiceResult(
      status: SiriVoiceStatus.registered,
      spoken: '登録しました',
      exercise: exercises.length == 1 ? exercises.single : null,
      exercises: exercises,
    );
  }
  final food = plan.food;
  final quantity = plan.quantity;
  if (food != null && quantity != null) {
    final entry = FoodEntry(
        id: newId(),
        name: food.speakName,
        kcalPerBase: food.kcalPerBase,
        proteinPerBase: food.proteinPerBase,
        fatPerBase: food.fatPerBase,
        carbPerBase: food.carbPerBase,
        baseAmount: food.baseAmount,
        unitType: food.unit,
        consumedAmount: quantity.amount,
        sourceType: food.source,
        savedFoodId: food.savedFoodId,
        sourceFoodOwnerUserId: food.sourceOwnerUserId,
        sourceSavedFoodVersion: food.version,
        officialFoodCode: food.officialFoodCode,
        officialFoodName: food.officialFoodName,
        loggedAt: loggedAt,
      );
    return SiriVoiceResult(
      status: SiriVoiceStatus.registered,
      spoken: '登録しました',
      food: entry,
      foods: [entry],
    );
  }
  final activityId = plan.activityId;
  if (activityId != null && quantity != null) {
    final exercise = buildSiriExerciseEntry(
      id: newId(),
      activityId: activityId,
      amount: quantity.amount,
      unit: quantity.unit,
      weightKg: weightKg,
      loggedAt: loggedAt,
    );
    if (exercise == null) {
      return const SiriVoiceResult(
        status: SiriVoiceStatus.unsupportedAmount,
        spoken: '計算できないので登録しません',
      );
    }
    return SiriVoiceResult(
      status: SiriVoiceStatus.registered,
      spoken: '登録しました',
      exercise: exercise,
      exercises: [exercise],
    );
  }
  return const SiriVoiceResult(
    status: SiriVoiceStatus.unsupportedAmount,
    spoken: '登録しません',
  );
}

ExerciseEntry? buildSiriExerciseEntry({
  required String id,
  required String activityId,
  required double amount,
  required SiriQuantityUnit unit,
  required double? weightKg,
  required DateTime loggedAt,
}) {
  final activity = MetActivityCatalog.findById(activityId);
  if (activity == null ||
      !activity.searchable ||
      activity.requiresManualKcal ||
      activity.quantityUnit == ExerciseQuantityUnit.reps) {
    return null;
  }
  if (activity.lifestyleIncluded) {
    if (unit != SiriQuantityUnit.minutes) {
      return null;
    }
    final minutes = amount.round();
    if (minutes <= 0 || minutes >= 24 * 60) {
      return null;
    }
    return ExerciseEntry(
      id: id,
      name: activity.displayName,
      durationMin: minutes,
      burnedKcal: 0,
      loggedAt: loggedAt,
      category: activity.category,
      activityId: activity.id,
      netKcal: 0,
      grossKcal: 0,
      calculationSource: ExerciseCalculationSource.lifestyleIncluded,
      calculationVersion: MetActivityCatalog.calculationVersion,
      sourceKey: activity.sourceKey,
    );
  }
  final weight = weightKg;
  if (weight == null || weight <= 0) {
    return null;
  }
  const calculator = ExerciseCalorieCalculator();
  switch (activity.quantityUnit) {
    case ExerciseQuantityUnit.durationMin:
      if (unit != SiriQuantityUnit.minutes || activity.calorieFormula == null) {
        return null;
      }
      final minutes = amount.round();
      final estimate = calculator.estimate(
        met: activity.defaultMet,
        weightKg: weight,
        durationMinutes: minutes,
        sourceKey: activity.sourceKey,
      );
      if (estimate == null) {
        return null;
      }
      return ExerciseEntry(
        id: id,
        name: activity.displayName,
        durationMin: minutes,
        burnedKcal: estimate.grossKcal,
        loggedAt: loggedAt,
        category: activity.category,
        activityId: activity.id,
        intensity: activity.defaultIntensityId,
        metValue: activity.defaultMet,
        grossKcal: estimate.grossKcal,
        netKcal: estimate.netKcal,
        weightKgSnapshot: weight,
        calculationSource: estimate.calculationSource,
        calculationVersion: estimate.calculationVersion,
        sourceKey: activity.sourceKey,
      );
    case ExerciseQuantityUnit.distanceKm:
      if (unit == SiriQuantityUnit.minutes) {
        final minutes = amount.round();
        final estimate = calculator.estimate(
          met: activity.defaultMet,
          weightKg: weight,
          durationMinutes: minutes,
          sourceKey: activity.sourceKey,
        );
        if (estimate == null) {
          return null;
        }
        return ExerciseEntry(
          id: id,
          name: activity.displayName,
          durationMin: minutes,
          burnedKcal: estimate.grossKcal,
          loggedAt: loggedAt,
          category: activity.category,
          activityId: activity.id,
          intensity: activity.defaultIntensityId,
          metValue: activity.defaultMet,
          grossKcal: estimate.grossKcal,
          netKcal: estimate.netKcal,
          weightKgSnapshot: weight,
          calculationSource: estimate.calculationSource,
          calculationVersion: estimate.calculationVersion,
          sourceKey: activity.sourceKey,
        );
      }
      if (unit != SiriQuantityUnit.kilometers) {
        return null;
      }
      final factor = activity.netKcalPerKgKm;
      final estimate = factor != null
          ? calculator.estimateByDistanceFactor(
              weightKg: weight,
              distanceKm: amount,
              netKcalPerKgKm: factor,
              sourceKey: activity.sourceKey,
            )
          : activity.referenceSpeedKmh == null
          ? null
          : calculator.estimateByDistanceSpeed(
              met: activity.defaultMet,
              weightKg: weight,
              distanceKm: amount,
              speedKmh: activity.referenceSpeedKmh!,
              sourceKey: activity.sourceKey,
            );
      if (estimate == null) {
        return null;
      }
      return ExerciseEntry(
        id: id,
        name: activity.displayName,
        durationMin: ExerciseCalorieCalculator.companionDurationMin(
          distanceKm: amount,
          referenceSpeedKmh: activity.referenceSpeedKmh,
        ),
        burnedKcal: estimate.grossKcal,
        loggedAt: loggedAt,
        category: activity.category,
        activityId: activity.id,
        intensity: activity.defaultIntensityId,
        distanceKm: amount,
        metValue: factor == null ? activity.defaultMet : null,
        grossKcal: estimate.grossKcal,
        netKcal: estimate.netKcal,
        weightKgSnapshot: weight,
        calculationSource: estimate.calculationSource,
        calculationVersion: estimate.calculationVersion,
        sourceKey: activity.sourceKey,
      );
    case ExerciseQuantityUnit.reps:
      return null;
  }
}

abstract final class SiriVoiceCodec {
  static String encodeCatalog({
    required String ownerUserId,
    required double? weightKg,
    required bool officialFoodsEnabled,
    required String supabaseUrl,
    required String supabaseAnonKey,
    required List<SiriFoodRecord> foods,
    List<SiriMealTemplate> mealTemplates = const [],
    List<SiriWorkoutTemplate> workoutTemplates = const [],
  }) {
    return jsonEncode({
      'version': 2,
      'ownerUserId': ownerUserId,
      'weightKg': weightKg,
      'officialFoodsEnabled': officialFoodsEnabled,
      'supabaseUrl': officialFoodsEnabled ? supabaseUrl : '',
      'supabaseAnonKey': officialFoodsEnabled ? supabaseAnonKey : '',
      'foods': [for (final food in foods) _foodJson(food)],
      'activities': [
        for (final activity in MetActivityCatalog.activities)
          if (activity.searchable)
            {
              'id': activity.id,
              'speakName': activity.displayName,
              'keys': [
                for (final alias in activity.aliases)
                  FoodSearchNormalizer.normalize(alias),
              ],
              'unit': activity.quantityUnit.name,
              'requiresManualKcal': activity.requiresManualKcal,
              'lifestyleIncluded': activity.lifestyleIncluded,
              'met': activity.defaultMet,
              'netKcalPerKgKm': activity.netKcalPerKgKm,
            },
      ],
      'mealTemplates': [
        for (final template in mealTemplates)
          {
            'id': template.id,
            'speakName': template.speakName,
            'keys': template.keys,
            'items': [
              for (final item in template.items)
                {
                  ..._foodJson(item.food),
                  'consumedAmount': item.consumedAmount,
                },
            ],
          },
      ],
      'workoutTemplates': [
        for (final template in workoutTemplates)
          {
            'id': template.id,
            'speakName': template.speakName,
            'keys': template.keys,
            'exercises': [
              for (final item in template.exercises)
                {
                  'activityId': item.activityId,
                  'minutes': item.minutes,
                  'kilometers': item.kilometers,
                },
            ],
          },
      ],
    });
  }

  static String encodePending({
    required String ownerUserId,
    FoodEntry? food,
    ExerciseEntry? exercise,
    double? weightKg,
  }) {
    final rows = <Map<String, Object?>>[];
    if (food != null) {
      rows.add({
        'kind': 'food',
        'id': food.id,
        'ownerUserId': ownerUserId,
        'loggedAt': formatLockScreenLoggedAt(food.loggedAt),
        'name': food.name,
        'baseAmount': food.baseAmount,
        'unit': food.unitType.storageValue,
        'consumedAmount': food.consumedAmount,
        'kcalPerBase': food.kcalPerBase,
        'proteinPerBase': food.proteinPerBase,
        'fatPerBase': food.fatPerBase,
        'carbPerBase': food.carbPerBase,
        'source': food.sourceType.storageValue,
        'savedFoodId': food.savedFoodId,
        'sourceOwnerUserId': food.sourceFoodOwnerUserId,
        'version': food.sourceSavedFoodVersion,
        'officialFoodCode': food.officialFoodCode,
        'officialFoodName': food.officialFoodName,
      });
    }
    if (exercise != null) {
      final unit = exercise.distanceKm != null
          ? SiriQuantityUnit.kilometers
          : SiriQuantityUnit.minutes;
      final amount = exercise.distanceKm ?? exercise.durationMin.toDouble();
      rows.add({
        'kind': 'exercise',
        'id': exercise.id,
        'ownerUserId': ownerUserId,
        'loggedAt': formatLockScreenLoggedAt(exercise.loggedAt),
        'activityId': exercise.activityId,
        'amount': amount,
        'quantityUnit': unit.name,
        'weightKg': weightKg ?? exercise.weightKgSnapshot,
      });
    }
    return jsonEncode(rows);
  }

  static SiriVoiceImportPlan decodePending({
    required String? raw,
    required String ownerUserId,
    required Set<String> existingFoodIds,
    required Set<String> existingExerciseIds,
  }) {
    if (raw == null || raw.trim().isEmpty) {
      return const SiriVoiceImportPlan(
        foods: [],
        exercises: [],
        acknowledgeIds: [],
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const SiriVoiceImportPlan(
        foods: [],
        exercises: [],
        acknowledgeIds: [],
      );
    }
    if (decoded is! List) {
      return const SiriVoiceImportPlan(
        foods: [],
        exercises: [],
        acknowledgeIds: [],
      );
    }
    final foods = <FoodEntry>[];
    final exercises = <ExerciseEntry>[];
    final acknowledgeIds = <String>[];
    for (final row in decoded) {
      if (row is! Map) {
        continue;
      }
      final id = _string(row['id']);
      final owner = _string(row['ownerUserId']);
      if (id == null || owner == null || owner != ownerUserId) {
        continue;
      }
      acknowledgeIds.add(id);
      final loggedAt = _loggedAt(row['loggedAt']);
      if (loggedAt == null) {
        continue;
      }
      if (row['kind'] == 'food') {
        if (existingFoodIds.contains(id)) {
          continue;
        }
        final entry = _foodEntry(row, id: id, loggedAt: loggedAt);
        if (entry != null) {
          foods.add(entry);
        }
        continue;
      }
      if (row['kind'] == 'exercise') {
        if (existingExerciseIds.contains(id)) {
          continue;
        }
        final amount = _double(row['amount']);
        final unit = _quantityUnit(_string(row['quantityUnit']));
        final activityId = _string(row['activityId']);
        if (amount == null || unit == null || activityId == null) {
          continue;
        }
        final entry = buildSiriExerciseEntry(
          id: id,
          activityId: activityId,
          amount: amount,
          unit: unit,
          weightKg: _double(row['weightKg']),
          loggedAt: loggedAt,
        );
        if (entry != null) {
          exercises.add(entry);
        }
      }
    }
    return SiriVoiceImportPlan(
      foods: foods,
      exercises: exercises,
      acknowledgeIds: acknowledgeIds,
    );
  }
}

SiriVoicePlan? _blocked(SiriVoiceContext context) {
  if (!context.paid) {
    return _stop(SiriVoiceStatus.unpaid, 'こちらはカロナビ+の機能です');
  }
  if (context.ownerUserId.trim().isEmpty) {
    return _stop(SiriVoiceStatus.signedOut, 'ログインしてください');
  }
  return null;
}

SiriVoicePlan _stop(SiriVoiceStatus status, String spoken) {
  return SiriVoicePlan._(
    status: status,
    spoken: spoken,
    asksConfirmation: false,
  );
}

SiriSpokenKind? _explicitSpokenKind(String source) {
  final meal = source.contains('食事に');
  final exercise = source.contains('運動に');
  if (meal == exercise) {
    return null;
  }
  return meal ? SiriSpokenKind.meal : SiriSpokenKind.exercise;
}

String _utterance(String name, String quantity) {
  final raw = quantity.trim().isEmpty
      ? name.trim()
      : '${name.trim()}${quantity.trim()}';
  return raw.replaceAll(' ', '').replaceAll('　', '');
}

bool _mentionsPhraseShape(String source) {
  return source.contains('カロナビ') ||
      source.contains('食事に') ||
      source.contains('運動に') ||
      source.contains('HeySiri') ||
      source.contains('heySiri');
}

({String name, String quantity}) _split(String name, String quantity) {
  if (parseSiriQuantity(quantity) != null &&
      !_mentionsPhraseShape(_utterance(name, ''))) {
    return (name: _cleanName(name), quantity: quantity.trim());
  }
  var source = quantity.trim().isEmpty
      ? name.trim()
      : '${name.trim()} ${quantity.trim()}';
  source = source.replaceFirst(RegExp(r'^(?:Hey|hey)\s*Siri[、,]?\s*'), '');
  final match = RegExp(
    r'^(?:カロナビで[、,]?)?(?:食事に|運動に)?(.+?)を\s*(\d.*)$',
  ).firstMatch(source);
  if (match != null) {
    return (name: match.group(1)!.trim(), quantity: match.group(2)!.trim());
  }
  final compact = source.replaceAll(' ', '').replaceAll('　', '');
  final tail = RegExp(
    '(\\d+(?:\\.\\d+)?)($_siriUnitPattern)\$',
  ).firstMatch(compact);
  if (tail != null) {
    final cleaned = _cleanName(compact.substring(0, tail.start));
    final spokenQuantity = '${tail.group(1)}${tail.group(2)}';
    if (cleaned.isNotEmpty && parseSiriQuantity(spokenQuantity) != null) {
      return (name: cleaned, quantity: spokenQuantity);
    }
  }
  final vague = splitSiriVagueTail(_cleanName(compact));
  if (vague != null && vague.name.trim().isNotEmpty) {
    return (name: vague.name, quantity: vague.vague);
  }
  return (name: _cleanName(name), quantity: quantity.trim());
}

const _siriUnitPattern =
    'ミリリットル|キロメートル|グラム|分間|食分|ml|mL|ML|ｍｌ|km|KM|㎞|キロ|個|こ|コ|食|分|回|g|G|ｇ';

String _cleanName(String raw) {
  var name = raw.trim();
  name = name.replaceFirst(RegExp(r'^(?:Hey|hey)\s*Siri[、,]?\s*'), '');
  name = name.replaceFirst(RegExp(r'^カロナビで[、,]?\s*'), '');
  if (name.startsWith('食事に')) {
    name = name.substring('食事に'.length);
  } else if (name.startsWith('運動に')) {
    name = name.substring('運動に'.length);
  }
  if (name.endsWith('を')) {
    name = name.substring(0, name.length - 1);
  }
  return name.trim();
}

bool _foodUnitFits(FoodUnitType foodUnit, SiriQuantityUnit spoken) {
  return switch (foodUnit) {
    FoodUnitType.g => spoken == SiriQuantityUnit.grams,
    FoodUnitType.ml => spoken == SiriQuantityUnit.milliliters,
    FoodUnitType.piece => spoken == SiriQuantityUnit.piece,
    FoodUnitType.serving => spoken == SiriQuantityUnit.serving,
  };
}

List<String> _keys(List<String?> texts) {
  final keys = <String>{};
  for (final text in texts) {
    final key = FoodSearchNormalizer.normalize(text);
    if (key.isNotEmpty) {
      keys.add(key);
    }
  }
  return keys.toList();
}

Map<String, Object?> _foodJson(SiriFoodRecord food) {
  return {
    'id': food.id,
    'speakName': food.speakName,
    'keys': food.keys,
    'baseAmount': food.baseAmount,
    'unit': food.unit.storageValue,
    'kcalPerBase': food.kcalPerBase,
    'proteinPerBase': food.proteinPerBase,
    'fatPerBase': food.fatPerBase,
    'carbPerBase': food.carbPerBase,
    'source': food.source.storageValue,
    'savedFoodId': food.savedFoodId,
    'sourceOwnerUserId': food.sourceOwnerUserId,
    'version': food.version,
    'officialFoodCode': food.officialFoodCode,
    'officialFoodName': food.officialFoodName,
    'isCandidate': food.isCandidate,
    'candidateRank': food.candidateRank,
    'priority': food.priority,
  };
}

FoodEntry? _foodEntry(
  Map row, {
  required String id,
  required DateTime loggedAt,
}) {
  final name = _string(row['name']);
  final base = _double(row['baseAmount']);
  final consumed = _double(row['consumedAmount']);
  final unit = FoodUnitTypeX.tryParse(_string(row['unit']));
  if (name == null ||
      base == null ||
      base <= 0 ||
      consumed == null ||
      consumed <= 0 ||
      unit == null) {
    return null;
  }
  final source =
      FoodEntrySourceX.tryParse(_string(row['source'])) ??
      FoodEntrySource.savedFood;
  return FoodEntry(
    id: id,
    name: name,
    kcalPerBase: _double(row['kcalPerBase']),
    proteinPerBase: _double(row['proteinPerBase']),
    fatPerBase: _double(row['fatPerBase']),
    carbPerBase: _double(row['carbPerBase']),
    baseAmount: base,
    unitType: unit,
    consumedAmount: consumed,
    sourceType: source,
    savedFoodId: _string(row['savedFoodId']),
    sourceFoodOwnerUserId: _string(row['sourceOwnerUserId']),
    sourceSavedFoodVersion: row['version'] == null
        ? null
        : _int(row['version']),
    officialFoodCode: _string(row['officialFoodCode']),
    officialFoodName: _string(row['officialFoodName']),
    loggedAt: loggedAt,
  );
}

SiriQuantityUnit? _quantityUnit(String? raw) {
  return switch (raw) {
    'grams' => SiriQuantityUnit.grams,
    'milliliters' => SiriQuantityUnit.milliliters,
    'piece' => SiriQuantityUnit.piece,
    'serving' => SiriQuantityUnit.serving,
    'minutes' => SiriQuantityUnit.minutes,
    'kilometers' => SiriQuantityUnit.kilometers,
    'reps' => SiriQuantityUnit.reps,
    _ => null,
  };
}

DateTime? _loggedAt(Object? raw) {
  final text = _string(raw);
  if (text == null) {
    return null;
  }
  try {
    return parseLockScreenLoggedAt(text);
  } on FormatException {
    return null;
  }
}

String? _string(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : value;
}

double? _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}
