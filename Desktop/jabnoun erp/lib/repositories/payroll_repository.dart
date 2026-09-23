import '../models/audit_log.dart' show CompanySettings;
import '../models/payslip.dart';
import '../services/payroll_calculator.dart';
import 'base_repository.dart';

class PayrollRepository extends BaseRepository {
  Future<PayrollParams> fetchPayrollParams() {
    return guard(() async {
      final data = await client.from('company_settings').select().limit(1).maybeSingle();
      if (data == null) return const PayrollParams();
      return PayrollParams.fromSettings(CompanySettings.fromMap(data));
    });
  }

  Future<List<Payslip>> fetchByMonth(DateTime month) {
    return guard(() async {
      final firstDay = DateTime(month.year, month.month, 1);
      final data = await client
          .from('payslips')
          .select()
          .eq('period_month', firstDay.toIso8601String().split('T').first)
          .order('created_at');
      return (data as List).map((e) => Payslip.fromMap(e as Map<String, Object?>)).toList();
    });
  }

  Future<Payslip?> fetchForEmployee(String employeeId, DateTime month) {
    return guard(() async {
      final firstDay = DateTime(month.year, month.month, 1);
      final data = await client
          .from('payslips')
          .select()
          .eq('employee_id', employeeId)
          .eq('period_month', firstDay.toIso8601String().split('T').first)
          .maybeSingle();
      if (data == null) return null;
      return Payslip.fromMap(data);
    });
  }

  Future<Payslip> generate({
    required String employeeId,
    required DateTime month,
    required double baseSalary,
    double bonuses = 0,
    double transportAllowance = 0,
    double otherAllowances = 0,
    int childrenCount = 0,
    bool isHouseholdHead = false,
    double otherDeductions = 0,
    String? notes,
    PayrollParams? params,
  }) {
    return guard(() async {
      final firstDay = DateTime(month.year, month.month, 1);
      final effectiveParams = params ?? await fetchPayrollParams();
      final result = PayrollCalculator.calculateWithParams(
        baseSalary: baseSalary,
        bonuses: bonuses,
        transportAllowance: transportAllowance,
        otherAllowances: otherAllowances,
        childrenCount: childrenCount,
        isHouseholdHead: isHouseholdHead,
        otherDeductions: otherDeductions,
        params: effectiveParams,
      );
      final payslip = Payslip(
        employeeId: employeeId,
        periodMonth: firstDay,
        baseSalary: baseSalary,
        bonuses: bonuses,
        transportAllowance: transportAllowance,
        otherAllowances: otherAllowances,
        grossSalary: result.grossSalary,
        cnssEmployee: result.cnssEmployee,
        taxableBase: result.taxableBase,
        irpp: result.irpp,
        css: result.css,
        otherDeductions: otherDeductions,
        netSalary: result.netSalary,
        notes: notes,
      );
      final data = await client
          .from('payslips')
          .upsert(
            {...payslip.toMap(), 'created_by': client.auth.currentUser?.id},
            onConflict: 'employee_id,period_month',
          )
          .select()
          .single();
      return Payslip.fromMap(data);
    });
  }

  Future<Payslip> update(String id, Map<String, dynamic> changes) {
    return guard(() async {
      final data = await client.from('payslips').update(changes).eq('id', id).select().single();
      return Payslip.fromMap(data);
    });
  }

  Future<void> delete(String id) {
    return guard(() => client.from('payslips').delete().eq('id', id));
  }
}
