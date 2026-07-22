/// base_amount を DB 保存前に小数第4位以内へ正規化する（D19）。
class BaseAmountNormalizer {
  const BaseAmountNormalizer._();

  static double normalize(double value) {
    return (value * 10000).roundToDouble() / 10000;
  }
}
