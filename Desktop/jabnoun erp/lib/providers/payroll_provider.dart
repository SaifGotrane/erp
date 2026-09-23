import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/payroll_repository.dart';
import '../models/payslip.dart';
import '../services/payroll_calculator.dart';

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) => PayrollRepository());

/// Taux et plafonds de paie configurés dans Paramètres (CNSS, CSS, etc.).
final payrollParamsProvider = FutureProvider<PayrollParams>((ref) {
  return ref.watch(payrollRepositoryProvider).fetchPayrollParams();
});

final selectedPayrollMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final payslipsForMonthProvider = FutureProvider.family<List<Payslip>, DateTime>((ref, month) async {
  final firstDay = DateTime(month.year, month.month, 1);
  return ref.watch(payrollRepositoryProvider).fetchByMonth(firstDay);
});
