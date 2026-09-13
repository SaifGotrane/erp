import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sale.dart';
import '../../models/sale_sub_invoice.dart';
import '../../providers/partner_provider.dart';
import '../../providers/phase4_8_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';

/// Permet de fractionner une facture principale en plusieurs sous-factures
/// attribuées à des sous-clients (existants ou générés), sans jamais
/// dépasser le montant total de la facture (voir §2 du cahier des charges).
void showSubInvoiceDialog(BuildContext context, WidgetRef ref, Sale sale) {
  showDialog(
    context: context,
    builder: (_) => _SubInvoiceDialog(sale: sale),
  );
}

class _SubInvoiceDialog extends ConsumerStatefulWidget {
  final Sale sale;
  const _SubInvoiceDialog({required this.sale});

  @override
  ConsumerState<_SubInvoiceDialog> createState() => _SubInvoiceDialogState();
}

class _SubInvoiceDialogState extends ConsumerState<_SubInvoiceDialog> {
  final _amountCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _existingCustomerId;
  bool _useExisting = false;
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _generateRandomName(List<SaleSubInvoice> existing) {
    final used = existing.map((e) => e.subClientName).toSet();
    final available = tunisianSampleNames.where((n) => !used.contains(n)).toList();
    final pool = available.isNotEmpty ? available : tunisianSampleNames;
    final name = pool[Random().nextInt(pool.length)];
    setState(() {
      _useExisting = false;
      _existingCustomerId = null;
      _nameCtrl.text = name;
    });
  }

  Future<void> _add(double remaining) async {
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      showAppSnackBar(context, 'Saisissez un montant positif.', isError: true);
      return;
    }
    if (amount > remaining + 0.001) {
      showAppSnackBar(
        context,
        'Montant refusé : il dépasse le solde restant à répartir (${remaining.toStringAsFixed(3)} TND).',
        isError: true,
      );
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      showAppSnackBar(context, 'Veuillez indiquer le nom du sous-client.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(saleRepositoryProvider).addSubInvoice(
            saleId: widget.sale.id,
            subClientName: _nameCtrl.text.trim(),
            amount: amount,
            customerId: _useExisting ? _existingCustomerId : null,
            notes: _notesCtrl.text.trim(),
          );
      ref.invalidate(saleSubInvoicesProvider(widget.sale.id));
      _amountCtrl.clear();
      _nameCtrl.clear();
      _notesCtrl.clear();
      setState(() {
        _useExisting = false;
        _existingCustomerId = null;
      });
      if (mounted) showAppSnackBar(context, 'Sous-facture ajoutée.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(SaleSubInvoice sub) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer la sous-facture',
      message: 'Supprimer la sous-facture ${sub.documentNumber} (${sub.subClientName}) ?',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(saleRepositoryProvider).deleteSubInvoice(sub.id);
      ref.invalidate(saleSubInvoicesProvider(widget.sale.id));
      if (mounted) showAppSnackBar(context, 'Sous-facture supprimée.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  void _reusePrevious(SaleSubInvoice previous) {
    setState(() {
      _useExisting = previous.customerId != null;
      _existingCustomerId = previous.customerId;
      _nameCtrl.text = previous.subClientName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final subInvoicesAsync = ref.watch(saleSubInvoicesProvider(widget.sale.id));
    final customersAsync = ref.watch(customerListProvider);
    final historyAsync = ref.watch(saleSubClientHistoryProvider(widget.sale.customerId));

    return AlertDialog(
      title: Text(
        'Sous-factures — ${widget.sale.documentNumber}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy),
      ),
      content: SizedBox(
        width: 560,
        child: subInvoicesAsync.when(
          data: (subInvoices) {
            final allocated = subInvoices.fold<double>(0, (sum, s) => sum + s.amount);
            final remaining = widget.sale.totalTtc - allocated;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text('Total facture: ${widget.sale.totalTtc.toStringAsFixed(3)} TND'),
                      Text('Alloué: ${allocated.toStringAsFixed(3)} TND'),
                      Text(
                        'Restant: ${remaining.toStringAsFixed(3)} TND',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: remaining > 0.001 ? AppColors.warning : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (subInvoices.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(6)),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: subInvoices.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = subInvoices[i];
                        return ListTile(
                          dense: true,
                          title: Text('${s.documentNumber} — ${s.subClientName}'),
                          subtitle: s.notes != null && s.notes!.isNotEmpty ? Text(s.notes!) : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${s.amount.toStringAsFixed(3)} TND', style: const TextStyle(fontWeight: FontWeight.w600)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                onPressed: () => _delete(s),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (remaining > 0.001) ...[
                  const Divider(),
                  const Text('Nouvelle sous-facture', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  historyAsync.when(
                    data: (history) {
                      final previous = history.where((h) => h.saleId != widget.sale.id).toList();
                      if (previous.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sous-clients déjà utilisés pour ce client :', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final h in previous)
                                  ActionChip(
                                    avatar: const Icon(Icons.history, size: 14),
                                    label: Text(h.subClientName),
                                    onPressed: () => _reusePrevious(h),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Client existant'),
                        selected: _useExisting,
                        onSelected: (v) => setState(() => _useExisting = v),
                      ),
                      ChoiceChip(
                        label: const Text('Nom généré'),
                        selected: !_useExisting,
                        onSelected: (v) => setState(() => _useExisting = !v),
                      ),
                      TextButton.icon(
                        onPressed: () => _generateRandomName(subInvoices),
                        icon: const Icon(Icons.casino_outlined, size: 16),
                        label: const Text('Générer un nom'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_useExisting)
                    customersAsync.when(
                      data: (customers) => DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _existingCustomerId,
                        decoration: const InputDecoration(labelText: 'Client'),
                        items: [for (final c in customers) DropdownMenuItem(value: c.id, child: Text(c.name))],
                        onChanged: (v) {
                          final c = customers.firstWhere((c) => c.id == v);
                          setState(() {
                            _existingCustomerId = v;
                            _nameCtrl.text = c.name;
                          });
                        },
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                    )
                  else
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nom du sous-client *'),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: 'Montant (max ${remaining.toStringAsFixed(3)}) *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _notesCtrl,
                          decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : () => _add(remaining),
                      icon: _saving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter la sous-facture'),
                    ),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(6)),
                    child: const Text(
                      'Le montant total de la facture est entièrement réparti.',
                      style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            );
          },
          loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text(e.toString(), style: const TextStyle(color: AppColors.danger)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
      ],
    );
  }
}
