import 'package:equatable/equatable.dart';

class Payslip extends Equatable {
  final String? id;
  final String employeeId;
  final DateTime periodMonth;
  final double baseSalary;
  final double bonuses;
  final double transportAllowance;
  final double otherAllowances;
  final double grossSalary;
  final double cnssEmployee;
  final double taxableBase;
  final double irpp;
  final double css;
  final double otherDeductions;
  final double netSalary;
  final String? notes;

  const Payslip({
    this.id,
    required this.employeeId,
    required this.periodMonth,
    required this.baseSalary,
    this.bonuses = 0,
    this.transportAllowance = 0,
    this.otherAllowances = 0,
    required this.grossSalary,
    required this.cnssEmployee,
    required this.taxableBase,
    required this.irpp,
    this.css = 0,
    this.otherDeductions = 0,
    required this.netSalary,
    this.notes,
  });

  factory Payslip.fromMap(Map<String, dynamic> map) {
    return Payslip(
      id: map['id'] as String?,
      employeeId: map['employee_id'] as String,
      periodMonth: DateTime.parse(map['period_month'] as String),
      baseSalary: (map['base_salary'] as num).toDouble(),
      bonuses: (map['bonuses'] as num? ?? 0).toDouble(),
      transportAllowance: (map['transport_allowance'] as num? ?? 0).toDouble(),
      otherAllowances: (map['other_allowances'] as num? ?? 0).toDouble(),
      grossSalary: (map['gross_salary'] as num).toDouble(),
      cnssEmployee: (map['cnss_employee'] as num).toDouble(),
      taxableBase: (map['taxable_base'] as num).toDouble(),
      irpp: (map['irpp'] as num).toDouble(),
      css: (map['css'] as num? ?? 0).toDouble(),
      otherDeductions: (map['other_deductions'] as num? ?? 0).toDouble(),
      netSalary: (map['net_salary'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employee_id': employeeId,
      'period_month': periodMonth.toIso8601String().split('T').first,
      'base_salary': baseSalary,
      'bonuses': bonuses,
      'transport_allowance': transportAllowance,
      'other_allowances': otherAllowances,
      'gross_salary': grossSalary,
      'cnss_employee': cnssEmployee,
      'taxable_base': taxableBase,
      'irpp': irpp,
      'css': css,
      'other_deductions': otherDeductions,
      'net_salary': netSalary,
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        employeeId,
        periodMonth,
        baseSalary,
        bonuses,
        transportAllowance,
        otherAllowances,
        grossSalary,
        cnssEmployee,
        taxableBase,
        irpp,
        css,
        otherDeductions,
        netSalary,
        notes,
      ];
}
