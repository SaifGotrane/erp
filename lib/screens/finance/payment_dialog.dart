import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/phase3_providers.dart';
import '../../providers/phase4_8_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';

/// Enregistre un règlement contre un document validé, sans permettre le
/// dépassement du solde restant.
void showPaymentDialog(
  BuildContext context,
  WidgetRef ref, {
  required String partnerType,
  required String partnerId,
  required String partnerName,
  required String documentId,
  required String documentNumber,
  required double remainingAmount,
}) {
  showDialog(
    context: context,
    builder: (_) => _PaymentDialog(
      partnerType: partnerType,
      partnerId: partnerId,
      partnerName: partnerName,
      documentId: documentId,
      documentNumber: documentNumber,
      remainingAmount: remainingAmount,
    ),
  );
}

class _PaymentDialog extends ConsumerStatefulWidget {
  final String partnerType;
  final String partnerId;
  final String partnerName;
  final String documentId;
  final String documentNumber;
  final double remainingAmount;

  const _PaymentDialog({
    required this.partnerType,
    required this.partnerId,
    required this.partnerName,
    required this.documentId,
    required this.documentNumber,
    required this.remainingAmount,
  });

  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.remainingAmount.toStringAsFixed(3),
  );
  final _notes = TextEditingController();
  String? _methodId;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0 || amount > widget.remainingAmount) {
      showAppSnackBar(
        context,
        'Saisissez un montant compris entre 0 et le solde restant.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(paymentRepositoryProvider)
          .recordPayment(
            paymentType: widget.partnerType == 'customer'
                ? 'encaissement'
                : 'decaissement',
            partnerType: widget.partnerType,
            partnerId: widget.partnerId,
            amount: amount,
            paymentMethodId: _methodId,
            saleId: widget.partnerType == 'customer' ? widget.documentId : null,
            purchaseId: widget.partnerType == 'supplier'
                ? widget.documentId
                : null,
            notes: _notes.text.trim(),
          );
      ref.invalidate(paymentListProvider);
      ref.invalidate(saleListProvider);
      ref.invalidate(purchaseListProvider);
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        showAppSnackBar(
          context,
          'Paiement enregistré pour ${widget.documentNumber}.',
        );
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = ref.watch(paymentMethodsProvider);
    return AlertDialog(
      title: const Text(
        'Enregistrer un paiement',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.partnerName} — ${widget.documentNumber}'),
            const SizedBox(height: 8),
            Text(
              'Solde restant : ${widget.remainingAmount.toStringAsFixed(3)} TND',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Montant (TND) *'),
            ),
            const SizedBox(height: 12),
            methods.when(
              data: (items) => DropdownButtonFormField<String?>(
                initialValue: _methodId,
                decoration: const InputDecoration(
                  labelText: 'Méthode de paiement',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  for (final item in items)
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: (value) => setState(() => _methodId = value),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
