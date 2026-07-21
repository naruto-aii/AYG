/// 食事の時間帯区分（表示用）。
enum MealSlot {
  breakfast('朝食'),
  lunch('昼食'),
  dinner('夕食'),
  snack('間食');

  const MealSlot(this.label);
  final String label;

  static const displayOrder = [
    MealSlot.breakfast,
    MealSlot.lunch,
    MealSlot.dinner,
    MealSlot.snack,
  ];
}

MealSlot mealSlotFromTime(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 11) {
    return MealSlot.breakfast;
  }
  if (hour >= 11 && hour < 15) {
    return MealSlot.lunch;
  }
  if (hour >= 17 && hour < 22) {
    return MealSlot.dinner;
  }
  return MealSlot.snack;
}
