import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/employee.dart';
import '../../models/payslip.dart';
import '../../providers/payroll_provider.dart';
import '../../services/payroll_calculator.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';

Future<void> showPayslipFormDialog(
  BuildContext context,
  WidgetRef ref, {
  required Employee employee,
  required DateTime month,
  Payslip? payslip,
}) {
  return showDialog(
    context: context,
    builder: (context) => _PayslipFormDialog(employee: employee, month: month, payslip: payslip),
  );
}

class _PayslipFormDialog extends ConsumerStatefulWidget {
  final Employee employee;
  final DateTime month;
  final Payslip? payslip;

  const _PayslipFormDialog({required this.employee, required this.month, this.payslip});

  @override
  ConsumerState<_PayslipFormDialog> createState() => _PayslipFormDialogState();
}

class _PayslipFormDialogState extends ConsumerState<_PayslipFormDialog> {
  final _baseSalary = TextEditingController();
  final _bonuses = TextEditingController();
  final _transport = TextEditingController();
  final _otherAllowances = TextEditingController();
  final _otherDeductions = TextEditingController();
  final _notes = TextEditingController();
  final _childrenCount = TextEditingController();
  bool _isHouseholdHead = false;
  bool _saving = false;
  PayrollParams _params = const PayrollParams();

  PayrollResult? _preview;

  @override
  void initState() {
    super.initState();
    final p = widget.payslip;
    _baseSalary.text = (p?.baseSalary ?? widget.employee.baseSalary).toStringAsFixed(3);
    _bonuses.text = (p?.bonuses ?? 0).toStringAsFixed(3);
    _transport.text = (p?.transportAllowance ?? 0).toStringAsFixed(3);
    _otherAllowances.text = (p?.otherAllowances ?? 0).toStringAsFixed(3);
    _otherDeductions.text = (p?.otherDeductions ?? 0).toStringAsFixed(3);
    _notes.text = p?.notes ?? '';
    _childrenCount.text = (widget.employee.childrenCount).toString();
    _isHouseholdHead = widget.employee.isHouseholdHead;
    _loadParams();
  }

  Future<void> _loadParams() async {
    try {
      _params = await ref.read(payrollRepositoryProvider).fetchPayrollParams();
    } catch (_) {
    } finally {
      if (mounted) _computePreview();
    }
  }

  @override
  void dispose() {
    _baseSalary.dispose();
    _bonuses.dispose();
    _transport.dispose();
    _otherAllowances.dispose();
    _otherDeductions.dispose();
    _notes.dispose();
    _childrenCount.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
  int _parseInt(TextEditingController c) => int.tryParse(c.text) ?? 0;

  void _computePreview() {
    setState(() {
      _preview = PayrollCalculator.calculateWithParams(
        baseSalary: _parse(_baseSalary),
        bonuses: _parse(_bonuses),
        transportAllowance: _parse(_transport),
        otherAllowances: _parse(_otherAllowances),
        childrenCount: _parseInt(_childrenCount),
        isHouseholdHead: _isHouseholdHead,
        otherDeductions: _parse(_otherDeductions),
        params: _params,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(payrollRepositoryProvider).generate(
            employeeId: widget.employee.id,
            month: widget.month,
            baseSalary: _parse(_baseSalary),
            bonuses: _parse(_bonuses),
            transportAllowance: _parse(_transport),
            otherAllowances: _parse(_otherAllowances),
            childrenCount: _parseInt(_childrenCount),
            isHouseholdHead: _isHouseholdHead,
            otherDeductions: _parse(_otherDeductions),
            notes: _notes.text,
            params: _params,
          );
      ref.invalidate(payslipsForMonthProvider(widget.month));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Fiche de paie — ${widget.employee.fullName}'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Période : ${_monthText(widget.month)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _baseSalary,
                decoration: const InputDecoration(labelText: 'Salaire de base (TND)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _computePreview(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bonuses,
                      decoration: const InputDecoration(labelText: 'Primes (TND)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _computePreview(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _transport,
                      decoration: const InputDecoration(labelText: 'Indemnité transport (TND)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _computePreview(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _otherAllowances,
                      decoration: const InputDecoration(labelText: 'Autres avantages (TND)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _computePreview(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _otherDeductions,
                      decoration: const InputDecoration(labelText: 'Autres retenues (TND)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _computePreview(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _childrenCount,
                      decoration: const InputDecoration(labelText: 'Enfants à charge'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _computePreview(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<bool>(
                      initialValue: _isHouseholdHead,
                      decoration: const InputDecoration(labelText: 'Chef de famille'),
                      items: const [
                        DropdownMenuItem(value: false, child: Text('Non')),
                        DropdownMenuItem(value: true, child: Text('Oui')),
                      ],
                      onChanged: (v) {
                        setState(() => _isHouseholdHead = v ?? false);
                        _computePreview();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              if (_preview != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _line('Salaire brut', _preview!.grossSalary),
                      _line('CNSS salarié (${(_params.cnssEmployeeRate * 100).toStringAsFixed(2)}%)', -_preview!.cnssEmployee),
                      _line('CSS (${(_params.cssRate * 100).toStringAsFixed(2)}%)', -_preview!.css),
                      _line('Base imposable', _preview!.taxableBase, isBold: true),
                      _line('IRPP', -_preview!.irpp),
                      _line('Autres retenues', -_parse(_otherDeductions)),
                      const Divider(),
                      _line('Salaire net', _preview!.netSalary, isBold: true, color: AppColors.success),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Générer'),
        ),
      ],
    );
  }

  Widget _line(String label, double value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.w700 : FontWeight.normal)),
          Text(
            '${value.toStringAsFixed(3)} TND',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _monthText(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
