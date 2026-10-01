import 'package:ayg/services/health_activity_excess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const excess = HealthActivityExcess();

  test(
    'returns zero unless health is linked and the value is above lifestyle',
    () {
      expect(
        excess.kcal(
          useHealthIntegration: false,
          basalReeKcal: 1600,
          lifestyleFactor: 1.55,
          activeEnergyBurnedKcal: 2000,
        ),
        0,
      );
      expect(
        excess.kcal(
          useHealthIntegration: true,
          basalReeKcal: null,
          lifestyleFactor: 1.55,
          activeEnergyBurnedKcal: 2000,
        ),
        0,
      );
      expect(
        excess.kcal(
          useHealthIntegration: true,
          basalReeKcal: 1600,
          lifestyleFactor: 1.55,
          activeEnergyBurnedKcal: null,
        ),
        0,
      );
      final allowance = 1600 * 0.55;
      expect(
        excess.kcal(
          useHealthIntegration: true,
          basalReeKcal: 1600,
          lifestyleFactor: 1.55,
          activeEnergyBurnedKcal: allowance,
        ),
        0,
      );
      expect(
        excess.kcal(
          useHealthIntegration: true,
          basalReeKcal: 1600,
          lifestyleFactor: 1.55,
          activeEnergyBurnedKcal: allowance + 40,
        ),
        closeTo(40, 0.001),
      );
    },
  );
}
