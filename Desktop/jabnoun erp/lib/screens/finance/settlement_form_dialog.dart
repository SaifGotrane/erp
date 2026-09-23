import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/audit_log.dart';
import '../../models/purchase.dart';
import '../../providers/bill_of_exchange_provider.dart';
import '../../providers/partner_provider.dart';
import '../../providers/phase3_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/partner_search_field.dart';

class _BillDraft {
  TextEditingController amount;
  DateTime dueDate;
  _BillDraft({required this.amount, required this.dueDate});
}

/// Fractionne une facture fournisseur validée en plusieurs lettres de
/// change (§1 du cahier des charges). Les informations bancaires manquantes
/// ne sont demandées qu'une seule fois pour tout le lot.
void showSettlementFormDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _SettlementFormDialog(),
  );
}

class _SettlementFormDialog extends ConsumerStatefulWidget {
  const _SettlementFormDialog();

  @override
  ConsumerState<_SettlementFormDialog> createState() => _SettlementFormDialogState();
}

class _SettlementFormDialogState extends ConsumerState<_SettlementFormDialog> {
  String? _supplierId;
  Purchase? _purchase;
  int _billCount = 3;
  final List<_BillDraft> _bills = [];

  // Missing-info collection (asked once for the whole batch).
  final _bankName = TextEditingController();
  final _bankAgency = TextEditingController();
  final _ribCodeBanque = TextEditingController();
  final _ribCodeAgence = TextEditingController();
  final _ribCompte = TextEditingController();
  final _ribCle = TextEditingController();
  final _billPlace = TextEditingController();
  final _avalInfo = TextEditingController();
  bool _saveAsDefault = true;
  bool _saving = false;

  @override
  void dispose() {
    for (final b in _bills) {
      b.amount.dispose();
    }
    _bankName.dispose();
    _bankAgency.dispose();
    _ribCodeBanque.dispose();
    _ribCodeAgence.dispose();
    _ribCompte.dispose();
    _ribCle.dispose();
    _billPlace.dispose();
    _avalInfo.dispose();
    super.dispose();
  }

  void _generateEqualSplit() {
    if (_purchase == null) return;
    for (final b in _bills) {
      b.amount.dispose();
    }
    _bills.clear();
    final total = _purchase!.totalTtc;
    final base = (total / _billCount * 1000).floor() / 1000;
    double allocated = 0;
    final now = DateTime.now();
    for (int i = 0; i < _billCount; i++) {
      final isLast = i == _billCount - 1;
      final amount = isLast ? double.parse((total - allocated).toStringAsFixed(3)) : base;
      allocated += base;
      _bills.add(_BillDraft(
        amount: TextEditingController(text: amount.toStringAsFixed(3)),
        dueDate: DateTime(now.year, now.month + i + 1, now.day),
      ));
    }
    setState(() {});
  }

  double get _billsSum => _bills.fold(0, (sum, b) => sum + (double.tryParse(b.amount.text.trim().replaceAll(',', '.')) ?? 0));

  void _prefillBankInfoFromSettings(CompanySettings settings) {
    if (_bankName.text.isEmpty) _bankName.text = settings.bankName ?? '';
    if (_bankAgency.text.isEmpty) _bankAgency.text = settings.bankAgency ?? '';
    if (_ribCodeBanque.text.isEmpty) _ribCodeBanque.text = settings.ribCodeBanque ?? '';
    if (_ribCodeAgence.text.isEmpty) _ribCodeAgence.text = settings.ribCodeAgence ?? '';
    if (_ribCompte.text.isEmpty) _ribCompte.text = settings.ribCompte ?? '';
    if (_ribCle.text.isEmpty) _ribCle.text = settings.ribCle ?? '';
    if (_billPlace.text.isEmpty) _billPlace.text = settings.defaultBillPlace ?? '';
  }

  bool get _missingBankInfo =>
      _bankName.text.trim().isEmpty ||
      _bankAgency.text.trim().isEmpty ||
      _ribCodeBanque.text.trim().isEmpty ||
      _ribCodeAgence.text.trim().isEmpty ||
      _ribCompte.text.trim().isEmpty ||
      _ribCle.text.trim().isEmpty ||
      _billPlace.text.trim().isEmpty;

  Future<void> _create() async {
    if (_purchase == null || _bills.isEmpty) {
      showAppSnackBar(context, 'Sélectionnez une facture et générez les lettres de change.', isError: true);
      return;
    }
    if ((_billsSum - _purchase!.totalTtc).abs() > 0.001) {
      showAppSnackBar(
        context,
        'La somme des lettres (${_billsSum.toStringAsFixed(3)}) doit être égale au total de la facture (${_purchase!.totalTtc.toStringAsFixed(3)}).',
        isError: true,
      );
      return;
    }
    if (_missingBankInfo) {
      showAppSnackBar(context, 'Veuillez compléter les informations bancaires (demandées une seule fois).', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      if (_saveAsDefault) {
        final settings = await ref.read(settingsRepositoryProvider).fetchSettings();
        await ref.read(settingsRepositoryProvider).updateSettings(CompanySettings(
              id: settings.id,
              companyName: settings.companyName,
              logoUrl: settings.logoUrl,
              address: settings.address,
              phone: settings.phone,
              email: settings.email,
              taxId: settings.taxId,
              currency: settings.currency,
              allowNegativeStock: settings.allowNegativeStock,
              bankName: _bankName.text.trim(),
              bankAgency: _bankAgency.text.trim(),
              ribCodeBanque: _ribCodeBanque.text.trim(),
              ribCodeAgence: _ribCodeAgence.text.trim(),
              ribCompte: _ribCompte.text.trim(),
              ribCle: _ribCle.text.trim(),
              defaultBillPlace: _billPlace.text.trim(),
            ));
      }

      await ref.read(billOfExchangeRepositoryProvider).createSettlement(
            supplierId: _supplierId!,
            purchaseId: _purchase!.id,
            bills: [
              for (final b in _bills)
                {
                  'amount': double.tryParse(b.amount.text.trim().replaceAll(',', '.')) ?? 0,
                  'due_date': b.dueDate.toIso8601String().split('T').first,
                },
            ],
            bankName: _bankName.text.trim(),
            bankAgency: _bankAgency.text.trim(),
            ribCodeBanque: _ribCodeBanque.text.trim(),
            ribCodeAgence: _ribCodeAgence.text.trim(),
            ribCompte: _ribCompte.text.trim(),
            ribCle: _ribCle.text.trim(),
            billPlace: _billPlace.text.trim(),
            avalInfo: _avalInfo.text.trim(),
          );

      ref.invalidate(billListProvider);
      ref.invalidate(settlementListProvider);
      if (mounted) Navigator.of(context).pop();
      if (mounted) showAppSnackBar(context, 'Règlement fournisseur créé avec ${_bills.length} lettre(s) de change.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(supplierListProvider);
    final settingsAsync = ref.watch(companySettingsOnceProvider);

    settingsAsync.whenData(_prefillBankInfoFromSettings);

    return AlertDialog(
      title: const Text('Règlement fournisseur — Lettres de change',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
      content: SizedBox(
        width: 640,
        height: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: suppliersAsync.when(
                    data: (suppliers) => PartnerSearchField(
                      partners: suppliers,
                      selectedId: _supplierId,
                      label: 'Fournisseur',
                      required: true,
                      onChanged: (v) => setState(() {
                        _supplierId = v;
                        _purchase = null;
                        _bills.clear();
                      }),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (_supplierId != null)
                Consumer(
                  builder: (context, ref, _) {
                    final purchasesAsync = ref.watch(_supplierPurchasesProvider(_supplierId!));
                    return purchasesAsync.when(
                      data: (purchases) {
                        // Seules les factures validées et non réglées peuvent être
                        // fractionnées en lettres de change (voir 0019_bills_of_exchange_fixes.sql).
                        final eligible = purchases.where((p) => p.status == 'valide').toList();
                        return DropdownButtonFormField<String>(
                          initialValue: _purchase?.id,
                          decoration: const InputDecoration(labelText: 'Facture fournisseur *'),
                          items: [
                            for (final p in eligible)
                              DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.documentNumber} — ${p.totalTtc.toStringAsFixed(3)} TND'),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            _purchase = eligible.firstWhere((p) => p.id == v);
                            _bills.clear();
                          }),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Erreur chargement factures'),
                    );
                  },
                ),
              if (_purchase != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Facture : ${_purchase!.documentNumber}'),
                      Text('Total : ${_purchase!.totalTtc.toStringAsFixed(3)} TND', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Nombre de lettres :'),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: _billCount.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true),
                        onChanged: (v) => _billCount = int.tryParse(v) ?? _billCount,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(onPressed: _generateEqualSplit, child: const Text('Répartir également')),
                  ],
                ),
                const SizedBox(height: 12),
                if (_bills.isNotEmpty) ...[
                  const Text('Échéancier (montants et dates modifiables)', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  for (int i = 0; i < _bills.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(width: 28, child: Text('${i + 1}.')),
                          Expanded(
                            child: TextField(
                              controller: _bills[i].amount,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(isDense: true, labelText: 'Montant'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _bills[i].dueDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) setState(() => _bills[i].dueDate = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(isDense: true, labelText: 'Échéance'),
                                child: Text('${_bills[i].dueDate.day}/${_bills[i].dueDate.month}/${_bills[i].dueDate.year}'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (_billsSum - _purchase!.totalTtc).abs() > 0.001 ? AppColors.dangerBg : AppColors.successBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Total des lettres : ${_billsSum.toStringAsFixed(3)} / ${_purchase!.totalTtc.toStringAsFixed(3)} TND',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: (_billsSum - _purchase!.totalTtc).abs() > 0.001 ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Informations manquantes (demandées une seule fois pour ce lot)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: _bankName, decoration: const InputDecoration(labelText: 'Banque *'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _bankAgency, decoration: const InputDecoration(labelText: 'Agence bancaire *'))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: _ribCodeBanque, decoration: const InputDecoration(labelText: 'Code banque *'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _ribCodeAgence, decoration: const InputDecoration(labelText: 'Code agence *'))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: _ribCompte, decoration: const InputDecoration(labelText: 'N° compte *'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _ribCle, decoration: const InputDecoration(labelText: 'Clé *'))),
                  ]),
                  const SizedBox(height: 8),
                  TextField(controller: _billPlace, decoration: const InputDecoration(labelText: 'Lieu de création *')),
                  const SizedBox(height: 8),
                  TextField(controller: _avalInfo, decoration: const InputDecoration(labelText: 'Aval (optionnel)')),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _saveAsDefault,
                    title: const Text('Enregistrer comme informations bancaires par défaut'),
                    onChanged: (v) => setState(() => _saveAsDefault = v ?? true),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _saving ? null : _create,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Créer les ${_bills.length} lettre(s) de change'),
        ),
      ],
    );
  }
}

final _supplierPurchasesProvider = FutureProvider.family((ref, String supplierId) {
  return ref.watch(purchaseRepositoryProvider).fetchAll(supplierId: supplierId);
});

final companySettingsOnceProvider = FutureProvider((ref) {
  return ref.watch(settingsRepositoryProvider).fetchSettings();
});
