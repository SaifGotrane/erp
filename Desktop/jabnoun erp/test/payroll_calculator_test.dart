import 'package:flutter_test/flutter_test.dart';
import 'package:jabnoun_erp/services/payroll_calculator.dart';

void main() {
  group('PayrollCalculator - barème IRPP 2025 (8 tranches)', () {
    test('salaire de 2000 TND, célibataire sans enfant', () {
      final r = PayrollCalculator.calculate(baseSalary: 2000);

      // CNSS = 2000 * 9.18%
      expect(r.grossSalary, 2000);
      expect(r.cnssEmployee, closeTo(183.6, 0.001));

      // Base annuelle = (2000 - 183.6) * 12 = 21796.8
      // Abattement frais pro = 10% plafonné à 2000
      // Base imposable annuelle = 19796.8 -> 1649.733/mois
      expect(r.taxableBase, closeTo(1649.733, 0.01));

      // IRPP annuel = 750 (tranche 15%) + 2449.2 (tranche 25%) = 3199.2
      expect(r.irpp, closeTo(266.6, 0.01));

      // CSS = 1% de la base imposable mensuelle
      expect(r.css, closeTo(16.497, 0.01));

      expect(r.netSalary, closeTo(1533.303, 0.01));
    });

    test('la première tranche annuelle (5000 TND) est exonérée', () {
      // Brut faible -> base imposable annuelle sous 5000 -> IRPP nul
      final r = PayrollCalculator.calculate(baseSalary: 400);
      expect(r.irpp, 0);
    });

    test('les déductions familiales réduisent l\'impôt', () {
      final single = PayrollCalculator.calculate(baseSalary: 2000);
      final family = PayrollCalculator.calculate(
        baseSalary: 2000,
        childrenCount: 2,
        isHouseholdHead: true,
      );

      expect(family.irpp, lessThan(single.irpp));
      expect(family.netSalary, greaterThan(single.netSalary));

      // 300 (chef de famille) + 2 x 100 = 500 TND/an déduits à 25% = 125/an
      expect(single.irpp - family.irpp, closeTo(125 / 12, 0.01));
    });

    test('les enfants à charge sont plafonnés à 4', () {
      final four = PayrollCalculator.calculate(baseSalary: 2000, childrenCount: 4);
      final six = PayrollCalculator.calculate(baseSalary: 2000, childrenCount: 6);
      expect(six.irpp, four.irpp);
    });

    test('primes et indemnités entrent dans le brut', () {
      final r = PayrollCalculator.calculate(
        baseSalary: 1500,
        bonuses: 200,
        transportAllowance: 100,
        otherAllowances: 50,
      );
      expect(r.grossSalary, 1850);
      expect(r.cnssEmployee, closeTo(1850 * 0.0918, 0.001));
    });

    test('les autres retenues diminuent uniquement le net', () {
      final without = PayrollCalculator.calculate(baseSalary: 2000);
      final with100 = PayrollCalculator.calculate(baseSalary: 2000, otherDeductions: 100);

      expect(with100.irpp, without.irpp);
      expect(with100.netSalary, closeTo(without.netSalary - 100, 0.001));
    });

    test('progressivité : le taux marginal supérieur est 40% au-delà de 70 000/an', () {
      final r = PayrollCalculator.calculate(baseSalary: 20000);
      // Base imposable annuelle bien au-delà de 70 000 -> IRPP > 0 et net < brut
      expect(r.irpp, greaterThan(0));
      expect(r.netSalary, lessThan(r.grossSalary));
    });

    test('la base imposable ne peut jamais être négative', () {
      final r = PayrollCalculator.calculate(baseSalary: 0);
      expect(r.taxableBase, 0);
      expect(r.irpp, 0);
      expect(r.netSalary, 0);
    });
  });
}
