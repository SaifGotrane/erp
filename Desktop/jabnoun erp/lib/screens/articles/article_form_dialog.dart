import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/article.dart';
import '../../providers/article_provider.dart';
import '../../widgets/common/confirm_dialog.dart';

Future<void> showArticleFormDialog(BuildContext context, WidgetRef ref, {Article? article}) {
  return showDialog(
    context: context,
    builder: (context) => _ArticleFormDialog(article: article),
  );
}

class _ArticleFormDialog extends ConsumerStatefulWidget {
  final Article? article;
  const _ArticleFormDialog({this.article});

  @override
  ConsumerState<_ArticleFormDialog> createState() => _ArticleFormDialogState();
}

class _ArticleFormDialogState extends ConsumerState<_ArticleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reference;
  late final TextEditingController _designation;
  late final TextEditingController _description;
  late final TextEditingController _barcode;
  late final TextEditingController _minStock;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _margin;
  String? _categoryId;
  String? _unitId;
  String? _taxRateId;
  bool _saving = false;

  bool get _isEdit => widget.article != null;

  @override
  void initState() {
    super.initState();
    final a = widget.article;
    _reference = TextEditingController(text: a?.reference ?? '');
    _designation = TextEditingController(text: a?.designation ?? '');
    _description = TextEditingController(text: a?.description ?? '');
    _barcode = TextEditingController(text: a?.barcode ?? '');
    _minStock = TextEditingController(text: a?.minStock.toString() ?? '0');
    _purchasePrice = TextEditingController(text: a?.purchasePriceHt.toString() ?? '0');
    _margin = TextEditingController(text: a?.marginPercent.toString() ?? '20');
    _categoryId = a?.categoryId;
    _unitId = a?.unitId;
    _taxRateId = a?.taxRateId.isEmpty ?? true ? null : a?.taxRateId;
  }

  @override
  void dispose() {
    for (final c in [_reference, _designation, _description, _barcode, _minStock, _purchasePrice, _margin]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _purchase => double.tryParse(_purchasePrice.text.trim().replaceAll(',', '.')) ?? 0;
  double get _marginValue => double.tryParse(_margin.text.trim().replaceAll(',', '.')) ?? 0;

  /// Permet de créer une catégorie sans quitter le formulaire d'article
  /// (voir cahier des charges §7) : ouvre une petite boîte de dialogue,
  /// crée la catégorie, l'ajoute à la liste et la sélectionne aussitôt.
  Future<void> _createCategoryInline() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nom de la catégorie'),
            onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final category = await ref.read(articleRepositoryProvider).createCategory(name);
      ref.invalidate(articleCategoriesProvider);
      setState(() => _categoryId = category.id);
      if (mounted) showAppSnackBar(context, 'Catégorie "$name" créée.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Future<void> _save(List<TaxRate> taxRates) async {
    if (!_formKey.currentState!.validate()) return;
    if (_taxRateId == null) {
      showAppSnackBar(context, 'Veuillez sélectionner un taux de TVA.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final taxRate = taxRates.firstWhere((t) => t.id == _taxRateId);
      final computed = Article.computeSellingPrice(
        purchasePriceHt: _purchase,
        marginPercent: _marginValue,
        taxRatePercent: taxRate.ratePercent,
      );
      final repo = ref.read(articleRepositoryProvider);
      final changes = {
        'reference': _reference.text.trim(),
        'designation': _designation.text.trim(),
        'category_id': _categoryId,
        'unit_id': _unitId,
        'description': _description.text.trim(),
        'barcode': _barcode.text.trim(),
        'min_stock': double.tryParse(_minStock.text.trim().replaceAll(',', '.')) ?? 0,
        'purchase_price_ht': _purchase,
        'tax_rate_id': _taxRateId,
        'tax_rate_percent': taxRate.ratePercent,
        'margin_percent': _marginValue,
        'selling_price_ht': computed.sellingHt,
        'selling_price_ttc': computed.sellingTtc,
      };
      if (_isEdit) {
        await repo.update(widget.article!.id, changes);
      } else {
        await repo.create(Article(
          id: '',
          reference: _reference.text.trim(),
          designation: _designation.text.trim(),
          categoryId: _categoryId,
          unitId: _unitId,
          description: _description.text.trim(),
          barcode: _barcode.text.trim(),
          minStock: double.tryParse(_minStock.text.trim().replaceAll(',', '.')) ?? 0,
          purchasePriceHt: _purchase,
          taxRateId: _taxRateId!,
          taxRatePercent: taxRate.ratePercent,
          marginPercent: _marginValue,
          sellingPriceHt: computed.sellingHt,
          sellingPriceTtc: computed.sellingTtc,
          active: true,
          createdAt: DateTime.now(),
        ));
      }
      ref.invalidate(articleListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(articleCategoriesProvider);
    final unitsAsync = ref.watch(articleUnitsProvider);
    final taxRatesAsync = ref.watch(taxRatesProvider);

    return AlertDialog(
      title: Text(_isEdit ? "Modifier l'article" : 'Nouvel article'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _reference,
                      decoration: const InputDecoration(labelText: 'Référence unique'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'La référence est requise.' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _designation,
                      decoration: const InputDecoration(labelText: 'Désignation'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'La désignation est requise.' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: categoriesAsync.when(
                      data: (categories) => Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _categoryId,
                              decoration: const InputDecoration(labelText: 'Catégorie'),
                              items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                              onChanged: (v) => setState(() => _categoryId = v),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            tooltip: 'Nouvelle catégorie',
                            onPressed: _createCategoryInline,
                          ),
                        ],
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: unitsAsync.when(
                      data: (units) => DropdownButtonFormField<String>(
                        initialValue: _unitId,
                        decoration: const InputDecoration(labelText: 'Unité'),
                        items: [for (final u in units) DropdownMenuItem(value: u.id, child: Text('${u.name} (${u.symbol})'))],
                        onChanged: (v) => setState(() => _unitId = v),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: _barcode, decoration: const InputDecoration(labelText: 'Code-barres (optionnel)')),
                const SizedBox(height: 12),
                TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minStock,
                      decoration: const InputDecoration(labelText: 'Stock minimum'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _purchasePrice,
                      decoration: const InputDecoration(labelText: "Prix d'achat HT"),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _margin,
                      decoration: const InputDecoration(labelText: 'Marge %'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: taxRatesAsync.when(
                      data: (rates) {
                        _taxRateId ??= rates.where((r) => r.isDefault).map((r) => r.id).firstOrNull;
                        return DropdownButtonFormField<String>(
                          initialValue: _taxRateId,
                          decoration: const InputDecoration(labelText: 'TVA'),
                          items: [for (final t in rates) DropdownMenuItem(value: t.id, child: Text('${t.label} (${t.ratePercent}%)'))],
                          onChanged: (v) => setState(() => _taxRateId = v),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                taxRatesAsync.maybeWhen(
                  data: (rates) {
                    final rate = rates.where((t) => t.id == _taxRateId).map((t) => t.ratePercent).firstOrNull ?? 0;
                    final computed = Article.computeSellingPrice(
                      purchasePriceHt: _purchase,
                      marginPercent: _marginValue,
                      taxRatePercent: rate,
                    );
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF2F5F8), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Prix de vente HT : ${computed.sellingHt.toStringAsFixed(3)}'),
                          Text('Prix de vente TTC : ${computed.sellingTtc.toStringAsFixed(3)}'),
                        ],
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        taxRatesAsync.maybeWhen(
          data: (rates) => ElevatedButton(
            onPressed: _saving ? null : () => _save(rates),
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enregistrer'),
          ),
          orElse: () => const ElevatedButton(onPressed: null, child: Text('Enregistrer')),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
