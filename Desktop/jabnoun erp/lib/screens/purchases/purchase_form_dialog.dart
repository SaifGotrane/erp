import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/article.dart';
import '../../models/purchase.dart';
import '../../providers/article_provider.dart';
import '../../providers/depot_provider.dart';
import '../../providers/partner_provider.dart';
import '../../providers/phase3_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/article_search_bar.dart';

class _LineEditor {
  String articleId;
  String articleReference;
  String articleDesignation;
  TextEditingController quantity;
  TextEditingController unitPriceHt;
  double taxRatePercent;
  TextEditingController discountPercent;

  _LineEditor({
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    required this.quantity,
    required this.unitPriceHt,
    required this.taxRatePercent,
    required this.discountPercent,
  });

  double get qty => double.tryParse(quantity.text.trim().replaceAll(',', '.')) ?? 0;
  double get price => double.tryParse(unitPriceHt.text.trim().replaceAll(',', '.')) ?? 0;
  double get disc => double.tryParse(discountPercent.text.trim().replaceAll(',', '.')) ?? 0;

  double get lineHt {
    final gross = qty * price;
    return gross * (1 - disc / 100);
  }

  double get lineTva => lineHt * taxRatePercent / 100;
  double get lineTtc => lineHt + lineTva;
}

void showPurchaseFormDialog(BuildContext context, WidgetRef ref, {Purchase? purchase}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PurchaseFormDialog(purchase: purchase),
  );
}

class PurchaseFormDialog extends ConsumerStatefulWidget {
  final Purchase? purchase;
  const PurchaseFormDialog({super.key, this.purchase});

  @override
  ConsumerState<PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends ConsumerState<PurchaseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supplierDocRef = TextEditingController();
  final _notes = TextEditingController();
  final _discountPercent = TextEditingController(text: '0');

  String? _supplierId;
  String? _depotId;
  String? _paymentMethodId;
  DateTime _purchaseDate = DateTime.now();
  final List<_LineEditor> _lines = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.purchase != null) {
      final p = widget.purchase!;
      _supplierId = p.supplierId;
      _depotId = p.depotId;
      _paymentMethodId = p.paymentMethodId;
      _supplierDocRef.text = p.supplierDocumentRef ?? '';
      _notes.text = p.notes ?? '';
      _discountPercent.text = p.discountPercent.toString();
      _purchaseDate = p.purchaseDate;
      for (final l in p.lines) {
        _lines.add(_LineEditor(
          articleId: l.articleId,
          articleReference: l.articleReference,
          articleDesignation: l.articleDesignation,
          quantity: TextEditingController(text: l.quantity.toString()),
          unitPriceHt: TextEditingController(text: l.unitPriceHt.toString()),
          taxRatePercent: l.taxRatePercent,
          discountPercent: TextEditingController(text: l.discountPercent.toString()),
        ));
      }
    }
  }

  @override
  void dispose() {
    _supplierDocRef.dispose();
    _notes.dispose();
    _discountPercent.dispose();
    for (final l in _lines) {
      l.quantity.dispose();
      l.unitPriceHt.dispose();
      l.discountPercent.dispose();
    }
    super.dispose();
  }

  double get _totalHt => _lines.fold(0, (sum, l) => sum + l.lineHt);
  double get _totalTva => _lines.fold(0, (sum, l) => sum + l.lineTva);
  double get _totalTtc => _totalHt + _totalTva;

  void _addLine(Article article) {
    setState(() {
      _lines.add(_LineEditor(
        articleId: article.id,
        articleReference: article.reference,
        articleDesignation: article.designation,
        quantity: TextEditingController(text: '1'),
        unitPriceHt: TextEditingController(text: article.purchasePriceHt.toString()),
        taxRatePercent: article.taxRatePercent,
        discountPercent: TextEditingController(text: '0'),
      ));
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].quantity.dispose();
      _lines[index].unitPriceHt.dispose();
      _lines[index].discountPercent.dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_supplierId == null || _depotId == null) {
      showAppSnackBar(context, 'Veuillez sélectionner un fournisseur et un dépôt.', isError: true);
      return;
    }
    if (_lines.isEmpty) {
      showAppSnackBar(context, 'Veuillez ajouter au moins une ligne.', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final lines = _lines
          .map((l) => PurchaseLine(
                id: '',
                purchaseId: '',
                articleId: l.articleId,
                quantity: l.qty,
                unitPriceHt: l.price,
                taxRatePercent: l.taxRatePercent,
                discountPercent: l.disc,
                lineTotalHt: l.lineHt,
                lineTotalTva: l.lineTva,
                lineTotalTtc: l.lineTtc,
              ))
          .toList();

      final repo = ref.read(purchaseRepositoryProvider);

      if (widget.purchase == null) {
        await repo.createDraft(
          supplierId: _supplierId!,
          depotId: _depotId!,
          purchaseDate: _purchaseDate,
          paymentMethodId: _paymentMethodId,
          supplierDocumentRef: _supplierDocRef.text.trim(),
          discountPercent: double.tryParse(_discountPercent.text.trim().replaceAll(',', '.')) ?? 0,
          notes: _notes.text.trim(),
          lines: lines,
        );
      } else {
        await repo.replaceLines(widget.purchase!.id, lines);
        await repo.updateDraft(widget.purchase!.id, {
          'supplier_id': _supplierId,
          'depot_id': _depotId,
          'payment_method_id': _paymentMethodId,
          'supplier_document_ref': _supplierDocRef.text.trim().isEmpty ? null : _supplierDocRef.text.trim(),
          'discount_percent': double.tryParse(_discountPercent.text.trim().replaceAll(',', '.')) ?? 0,
          'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          'purchase_date': _purchaseDate.toIso8601String().split('T').first,
          'total_ht': _totalHt,
          'total_tva': _totalTva,
          'total_ttc': _totalTtc,
        });
      }

      ref.invalidate(purchaseListProvider);
      if (mounted) Navigator.of(context).pop();
      if (mounted) showAppSnackBar(context, 'Achat enregistré avec succès.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(supplierListProvider);
    final depotsAsync = ref.watch(activeDepotsProvider);
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

    return AlertDialog(
      title: Text(widget.purchase == null ? 'Nouvel achat' : 'Modifier l\'achat',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navy)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: suppliersAsync.when(
                      data: (suppliers) => DropdownButtonFormField<String>(
                        initialValue: _supplierId,
                        decoration: const InputDecoration(labelText: 'Fournisseur *'),
                        items: [for (final s in suppliers) DropdownMenuItem(value: s.id, child: Text(s.name))],
                        onChanged: (v) => setState(() => _supplierId = v),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Erreur chargement fournisseurs'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: depotsAsync.when(
                      data: (depots) => DropdownButtonFormField<String>(
                        initialValue: _depotId,
                        decoration: const InputDecoration(labelText: 'Dépôt de réception *'),
                        items: [for (final d in depots) DropdownMenuItem(value: d.id, child: Text(d.name))],
                        onChanged: (v) => setState(() => _depotId = v),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Erreur chargement dépôts'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _supplierDocRef,
                      decoration: const InputDecoration(labelText: 'Référence facture fournisseur (optionnel)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: paymentMethodsAsync.when(
                      data: (methods) => DropdownButtonFormField<String?>(
                        initialValue: _paymentMethodId,
                        decoration: const InputDecoration(labelText: 'Méthode de paiement'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('—')),
                          for (final m in methods) DropdownMenuItem(value: m.id, child: Text(m.name)),
                        ],
                        onChanged: (v) => setState(() => _paymentMethodId = v),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _purchaseDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _purchaseDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date'),
                        child: Text('${_purchaseDate.day}/${_purchaseDate.month}/${_purchaseDate.year}'),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Lignes d\'articles', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.navy)),
                  ],
                ),
                ArticleSearchBar(onSelected: _addLine),
                const SizedBox(height: 8),
                if (_lines.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                    child: const Text('Aucune ligne. Cliquez sur + pour ajouter un article.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  )
                else
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(6)),
                    child: Column(
                      children: [
                        Container(
                          color: AppColors.tableHeaderBg,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            children: const [
                              Expanded(flex: 3, child: Text('Article', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                              Expanded(flex: 1, child: Text('Qté', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                              Expanded(flex: 1, child: Text('Prix HT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                              Expanded(flex: 1, child: Text('TVA%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                              Expanded(flex: 1, child: Text('Remise%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                              Expanded(flex: 1, child: Text('Total HT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                              SizedBox(width: 32),
                            ],
                          ),
                        ),
                        for (int i = 0; i < _lines.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Text('${_lines[i].articleReference}\n${_lines[i].articleDesignation}', style: const TextStyle(fontSize: 12))),
                                Expanded(flex: 1, child: TextField(controller: _lines[i].quantity, style: const TextStyle(fontSize: 12), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), onTapOutside: (_) => setState(() {}))),
                                Expanded(flex: 1, child: Padding(padding: const EdgeInsets.only(left: 4), child: TextField(controller: _lines[i].unitPriceHt, style: const TextStyle(fontSize: 12), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), onTapOutside: (_) => setState(() {})))),
                                Expanded(flex: 1, child: Padding(padding: const EdgeInsets.only(left: 4), child: Text('${_lines[i].taxRatePercent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)))),
                                Expanded(flex: 1, child: Padding(padding: const EdgeInsets.only(left: 4), child: TextField(controller: _lines[i].discountPercent, style: const TextStyle(fontSize: 12), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), onTapOutside: (_) => setState(() {})))),
                                Expanded(flex: 1, child: Padding(padding: const EdgeInsets.only(left: 4), child: Text(_lines[i].lineHt.toStringAsFixed(3), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))),
                                SizedBox(
                                  width: 32,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
                                    onPressed: () => _removeLine(i),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF2F5F8), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total HT: ${_totalHt.toStringAsFixed(3)}'),
                      Text('Total TVA: ${_totalTva.toStringAsFixed(3)}'),
                      Text('Total TTC: ${_totalTtc.toStringAsFixed(3)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optionnel)'), maxLines: 2),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
