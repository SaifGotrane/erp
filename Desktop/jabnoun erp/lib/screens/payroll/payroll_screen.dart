import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/employee.dart';
import '../../services/payroll_pdf_service.dart';
import '../../models/payslip.dart';
import '../../providers/employee_provider.dart';
import '../../providers/payroll_provider.dart';
import '../../services/payroll_calculator.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/scrollable_table.dart';
import 'payslip_form_dialog.dart';

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedPayrollMonthProvider);
    final payslipsAsync = ref.watch(payslipsForMonthProvider(month));
    final employeesAsync = ref.watch(employeeListProvider);

    return PageScaffold(
      title: 'Fiches de paie',
      subtitle: 'Paie mensuelle des employés',
      actions: [
        _MonthPicker(month: month),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummary(payslipsAsync),
            const SizedBox(height: 16),
            Expanded(
              child: employeesAsync.when(
                data: (employees) => payslipsAsync.when(
                  data: (payslips) => _buildTable(context, ref, employees, payslips, month),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.danger))),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.danger))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(AsyncValue<List<Payslip>> async) {
    return async.when(
      data: (payslips) {
        final totalNet = payslips.fold<double>(0, (sum, p) => sum + p.netSalary);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
          child: Text(
            'Total net versé : ${totalNet.toStringAsFixed(3)} TND — ${payslips.length} fiche${payslips.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildTable(BuildContext context, WidgetRef ref, List<Employee> employees, List<Payslip> payslips, DateTime month) {
    final map = {for (final p in payslips) p.employeeId: p};

    return ScrollableTable(
      table: DataTable(
        columns: const [
          DataColumn(label: Text('Employé')),
          DataColumn(label: Text('Salaire de base')),
          DataColumn(label: Text('Brut')),
          DataColumn(label: Text('CNSS')),
          DataColumn(label: Text('IRPP')),
          DataColumn(label: Text('CSS')),
          DataColumn(label: Text('Net')),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (final e in employees)
            DataRow(
              cells: [
                DataCell(Text(e.fullName)),
                DataCell(Text('${e.baseSalary.toStringAsFixed(3)} TND')),
                DataCell(Text('${(map[e.id]?.grossSalary ?? e.baseSalary).toStringAsFixed(3)} TND')),
                DataCell(Text('${(map[e.id]?.cnssEmployee ?? 0).toStringAsFixed(3)} TND')),
                DataCell(Text('${(map[e.id]?.irpp ?? 0).toStringAsFixed(3)} TND')),
                DataCell(Text('${(map[e.id]?.css ?? 0).toStringAsFixed(3)} TND')),
                DataCell(Text('${(map[e.id]?.netSalary ?? _estimateNet(e)).toStringAsFixed(3)} TND')),
                DataCell(_rowActions(context, ref, e, map[e.id], month)),
              ],
            ),
        ],
      ),
    );
  }

  double _estimateNet(Employee e) {
    final result = PayrollCalculator.calculate(
      baseSalary: e.baseSalary,
      childrenCount: e.childrenCount,
      isHouseholdHead: e.isHouseholdHead,
    );
    return result.netSalary;
  }

  Widget _rowActions(BuildContext context, WidgetRef ref, Employee e, Payslip? payslip, DateTime month) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.calculate_outlined, size: 18, color: AppColors.primary),
          tooltip: payslip == null ? 'Générer la fiche de paie' : 'Modifier la fiche de paie',
          onPressed: () => showPayslipFormDialog(context, ref, employee: e, month: month, payslip: payslip),
        ),
        if (payslip != null)
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.textSecondary),
            tooltip: 'Télécharger PDF',
            onPressed: () async {
              try {
                await PayrollPdfService().generatePayslip(payslip, e);
                if (context.mounted) showAppSnackBar(context, 'Fiche de paie générée.');
              } catch (err) {
                if (context.mounted) showAppSnackBar(context, err.toString(), isError: true);
              }
            },
          ),
        if (payslip != null)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
            tooltip: 'Supprimer',
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'Supprimer la fiche de paie',
                message: 'Supprimer la fiche de paie de ${e.fullName} pour ${_formatMonth(month)} ?',
                confirmLabel: 'Supprimer',
                danger: true,
              );
              if (ok) {
                await ref.read(payrollRepositoryProvider).delete(payslip.id!);
                ref.invalidate(payslipsForMonthProvider(month));
                if (context.mounted) showAppSnackBar(context, 'Fiche de paie supprimée.');
              }
            },
          ),
      ],
    );
  }

  String _formatMonth(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _MonthPicker extends ConsumerWidget {
  final DateTime month;
  const _MonthPicker({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: month,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDatePickerMode: DatePickerMode.year,
          helpText: 'Sélectionner un mois',
        );
        if (picked != null) {
          ref.read(selectedPayrollMonthProvider.notifier).state = DateTime(picked.year, picked.month, 1);
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              '${month.month.toString().padLeft(2, '0')}/${month.year}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
