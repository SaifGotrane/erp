import '../models/audit_log.dart' show CompanySettings;

class PayrollResult {
  final double grossSalary;
  final double cnssEmployee;
  final double css;
  final double taxableBase;
  final double irpp;
  final double netSalary;

  const PayrollResult({
    required this.grossSalary,
    required this.cnssEmployee,
    required this.css,
    required this.taxableBase,
    required this.irpp,
    required this.netSalary,
  });
}

/// Taux et plafonds configurables (voir company_settings) utilisés pour
/// le calcul de la paie. Permet à chaque entreprise d'ajuster les taux
/// CNSS/CSS et les plafonds de déductions sans modifier le code.
class PayrollParams {
  final double cnssEmployeeRate;
  final double cssRate;
  final double professionalExpensesRate;
  final double professionalExpensesAnnualCap;
  final double headOfHouseholdAnnualDeduction;
  final double childAnnualDeduction;
  final int maxDeductibleChildren;

  const PayrollParams({
    this.cnssEmployeeRate = 0.0918,
    this.cssRate = 0.01,
    this.professionalExpensesRate = 0.10,
    this.professionalExpensesAnnualCap = 2000,
    this.headOfHouseholdAnnualDeduction = 300,
    this.childAnnualDeduction = 100,
    this.maxDeductibleChildren = 4,
  });

  factory PayrollParams.fromSettings(CompanySettings settings) => PayrollParams(
        cnssEmployeeRate: settings.cnssEmployeeRate,
        cssRate: settings.cssRate,
        professionalExpensesRate: settings.professionalExpensesRate,
        professionalExpensesAnnualCap: settings.professionalExpensesAnnualCap,
        headOfHouseholdAnnualDeduction: settings.headOfHouseholdAnnualDeduction,
        childAnnualDeduction: settings.childAnnualDeduction,
        maxDeductibleChildren: settings.maxDeductibleChildren,
      );
}

/// Calcul de paie mensuelle selon la législation tunisienne.
///
/// Ordre de calcul (méthode officielle brut -> net) :
/// 1. Brut = salaire de base + primes + indemnités.
/// 2. CNSS salarié = 9.18% du brut (régime des salariés non agricoles),
///    configurable via [PayrollParams].
/// 3. Revenu imposable = brut - CNSS.
/// 4. Abattement frais professionnels = 10% du revenu imposable,
///    plafonné à 2 000 TND/an (166.667 TND/mois), configurable.
/// 5. Déductions familiales : chef de famille 300 TND/an,
///    enfant à charge 100 TND/an (maximum 4 enfants), configurable.
/// 6. IRPP = barème progressif à 8 tranches (art. 36 de la loi n°2024-48
///    du 9 décembre 2024, loi de finances 2025), appliqué sur la base
///    imposable annualisée puis ramené au mois.
/// 7. CSS (contribution sociale de solidarité) = 1% de la base imposable,
///    configurable.
/// 8. Net = brut - CNSS - IRPP - CSS - autres retenues.
class PayrollCalculator {
  static const double cnssEmployeeRate = 0.0918;
  static const double cssRate = 0.01;

  static const double _professionalExpensesRate = 0.10;
  static const double _professionalExpensesAnnualCap = 2000.0;

  static const double _headOfHouseholdAnnualDeduction = 300.0;
  static const double _childAnnualDeduction = 100.0;
  static const int _maxDeductibleChildren = 4;

  /// Barème IRPP annuel en vigueur (loi de finances 2025).
  static const List<_Bracket> _brackets = [
    _Bracket(0, 5000, 0.00),
    _Bracket(5000, 10000, 0.15),
    _Bracket(10000, 20000, 0.25),
    _Bracket(20000, 30000, 0.30),
    _Bracket(30000, 40000, 0.33),
    _Bracket(40000, 50000, 0.36),
    _Bracket(50000, 70000, 0.38),
    _Bracket(70000, double.infinity, 0.40),
  ];

  static PayrollResult calculate({
    required double baseSalary,
    double bonuses = 0,
    double transportAllowance = 0,
    double otherAllowances = 0,
    int childrenCount = 0,
    bool isHouseholdHead = false,
    double otherDeductions = 0,
    double? cnssEmployeeRateOverride,
    double? cssRateOverride,
    double? professionalExpensesRateOverride,
    double? professionalExpensesAnnualCapOverride,
    double? headOfHouseholdAnnualDeductionOverride,
    double? childAnnualDeductionOverride,
    int? maxDeductibleChildrenOverride,
  }) {
    final effectiveCnssRate = cnssEmployeeRateOverride ?? cnssEmployeeRate;
    final effectiveCssRate = cssRateOverride ?? cssRate;
    final effectiveProfessionalExpensesRate =
        professionalExpensesRateOverride ?? _professionalExpensesRate;
    final effectiveProfessionalExpensesAnnualCap =
        professionalExpensesAnnualCapOverride ?? _professionalExpensesAnnualCap;
    final effectiveHeadOfHouseholdAnnualDeduction =
        headOfHouseholdAnnualDeductionOverride ?? _headOfHouseholdAnnualDeduction;
    final effectiveChildAnnualDeduction = childAnnualDeductionOverride ?? _childAnnualDeduction;
    final effectiveMaxDeductibleChildren =
        maxDeductibleChildrenOverride ?? _maxDeductibleChildren;

    final gross = baseSalary + bonuses + transportAllowance + otherAllowances;

    final cnss = gross * effectiveCnssRate;

    // Tout le calcul IRPP se fait sur une base annuelle puis est ramené au mois.
    final annualTaxableIncome = (gross - cnss) * 12;

    var professionalDeduction = annualTaxableIncome * effectiveProfessionalExpensesRate;
    if (professionalDeduction > effectiveProfessionalExpensesAnnualCap) {
      professionalDeduction = effectiveProfessionalExpensesAnnualCap;
    }

    final deductibleChildren = childrenCount > effectiveMaxDeductibleChildren
        ? effectiveMaxDeductibleChildren
        : childrenCount;
    var familyDeduction = deductibleChildren * effectiveChildAnnualDeduction;
    if (isHouseholdHead) familyDeduction += effectiveHeadOfHouseholdAnnualDeduction;

    var annualTaxableBase = annualTaxableIncome - professionalDeduction - familyDeduction;
    if (annualTaxableBase < 0) annualTaxableBase = 0;

    final irpp = _computeAnnualIrpp(annualTaxableBase) / 12;
    final monthlyTaxableBase = annualTaxableBase / 12;
    final css = monthlyTaxableBase * effectiveCssRate;

    final net = gross - cnss - irpp - css - otherDeductions;

    return PayrollResult(
      grossSalary: _round(gross),
      cnssEmployee: _round(cnss),
      css: _round(css),
      taxableBase: _round(monthlyTaxableBase),
      irpp: _round(irpp),
      netSalary: _round(net),
    );
  }

  /// Variante pratique de [calculate] prenant directement un [PayrollParams]
  /// (chargé depuis `company_settings`) au lieu de sept overrides distincts.
  static PayrollResult calculateWithParams({
    required double baseSalary,
    double bonuses = 0,
    double transportAllowance = 0,
    double otherAllowances = 0,
    int childrenCount = 0,
    bool isHouseholdHead = false,
    double otherDeductions = 0,
    PayrollParams params = const PayrollParams(),
  }) {
    return calculate(
      baseSalary: baseSalary,
      bonuses: bonuses,
      transportAllowance: transportAllowance,
      otherAllowances: otherAllowances,
      childrenCount: childrenCount,
      isHouseholdHead: isHouseholdHead,
      otherDeductions: otherDeductions,
      cnssEmployeeRateOverride: params.cnssEmployeeRate,
      cssRateOverride: params.cssRate,
      professionalExpensesRateOverride: params.professionalExpensesRate,
      professionalExpensesAnnualCapOverride: params.professionalExpensesAnnualCap,
      headOfHouseholdAnnualDeductionOverride: params.headOfHouseholdAnnualDeduction,
      childAnnualDeductionOverride: params.childAnnualDeduction,
      maxDeductibleChildrenOverride: params.maxDeductibleChildren,
    );
  }

  /// Applique le barème progressif : chaque tranche n'est imposée qu'à son
  /// propre taux, sur la fraction du revenu qui la traverse.
  static double _computeAnnualIrpp(double annualTaxableBase) {
    var tax = 0.0;
    for (final bracket in _brackets) {
      if (annualTaxableBase <= bracket.lower) break;
      final upper =
          annualTaxableBase < bracket.upper ? annualTaxableBase : bracket.upper;
      tax += (upper - bracket.lower) * bracket.rate;
    }
    return tax;
  }

  static double _round(double value) => double.parse(value.toStringAsFixed(3));
}

class _Bracket {
  final double lower;
  final double upper;
  final double rate;
  const _Bracket(this.lower, this.upper, this.rate);
}
