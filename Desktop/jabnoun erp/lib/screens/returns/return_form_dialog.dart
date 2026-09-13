import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/article.dart';
import '../../models/returns.dart';
import '../../providers/article_provider.dart';
import '../../providers/depot_provider.dart';
import '../../providers/phase4_8_providers.dart';
import '../../providers/partner_provider.dart';
import '../../providers/showroom_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/article_search_bar.dart';
import '../../widgets/common/partner_search_field.dart';
import '../../widgets/common/location_search_field.dart';

class _ReturnLineEditor {
  String articleId;
  String articleReference;
  String articleDesignation;
  TextEditingController quantity;
  TextEditingController unitPriceHt;
  double taxRatePercent;

  _ReturnLineEditor({
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    required this.quantity,
    required this.unitPriceHt,
    required this.taxRatePercent,
  });

  double get qty =>
      double.tryParse(quantity.text.trim().replaceAll(',', '.')) ?? 0;
  double get price =>
      double.tryParse(unitPriceHt.text.trim().replaceAll(',', '.')) ?? 0;
  double get lineHt => qty * price;
  double get lineTva => lineHt * taxRatePercent / 100;
  double get lineTtc => lineHt + lineTva;
}

void showSupplierReturnFormDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _SupplierReturnFormDialog(),
  );
}

class _SupplierReturnFormDialog extends ConsumerStatefulWidget {
  const _SupplierReturnFormDialog();

  @override
  ConsumerState<_SupplierReturnFormDialog> createState() =>
      _SupplierReturnFormDialogState();
}

class _SupplierReturnFormDialogState
    extends ConsumerState<_SupplierReturnFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();

  String? _supplierId;
  String? _depotId;
  DateTime _returnDate = DateTime.now();
  final List<_ReturnLineEditor> _lines = [];
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    for (final l in _lines) {
      l.quantity.dispose();
      l.unitPriceHt.dispose();
    }
    super.dispose();
  }

  double get _totalHt => _lines.fold(0, (sum, l) => sum + l.lineHt);
  double get _totalTva => _lines.fold(0, (sum, l) => sum + l.lineTva);
  double get _totalTtc => _totalHt + _totalTva;

  void _addLine(Article article) {
    setState(() {
      _lines.add(
        _ReturnLineEditor(
          articleId: article.id,
          articleReference: article.reference,
          articleDesignation: article.designation,
          quantity: TextEditingController(text: '1'),
          unitPriceHt: TextEditingController(
            text: article.purchasePriceHt.toString(),
          ),
          taxRatePercent: article.taxRatePercent,
        ),
      );
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].quantity.dispose();
      _lines[index].unitPriceHt.dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_supplierId == null) {
      showAppSnackBar(
        context,
        'Veuillez sélectionner un fournisseur.',
        isError: true,
      );
      return;
    }
    if (_depotId == null) {
      showAppSnackBar(
        context,
        'Veuillez sélectionner un dépôt.',
        isError: true,
      );
      return;
    }
    if (_lines.isEmpty) {
      showAppSnackBar(
        context,
        'Veuillez ajouter au moins une ligne.',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final lines = _lines
          .map(
            (l) => SupplierReturnLine(
              id: '',
              returnId: '',
              articleId: l.articleId,
              quantity: l.qty,
              unitPriceHt: l.price,
              taxRatePercent: l.taxRatePercent,
              lineTotalHt: l.lineHt,
              lineTotalTva: l.lineTva,
              lineTotalTtc: l.lineTtc,
            ),
          )
          .toList();

      await ref
          .read(supplierReturnRepositoryProvider)
          .createDraft(
            supplierId: _supplierId!,
            depotId: _depotId!,
            returnDate: _returnDate,
            notes: _notes.text.trim(),
            lines: lines,
          );

      ref.invalidate(supplierReturnListProvider);
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        showAppSnackBar(context, 'Retour fournisseur créé avec succès.');
      }
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

    return AlertDialog(
      title: const Text(
        'Nouveau retour fournisseur',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
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
                Row(
                  children: [
                    Expanded(
                      child: suppliersAsync.when(
                        data: (suppliers) => PartnerSearchField(
                          partners: suppliers,
                          selectedId: _supplierId,
                          label: 'Fournisseur',
                          required: true,
                          onChanged: (v) => setState(() => _supplierId = v),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) =>
                            const Text('Erreur chargement fournisseurs'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: depotsAsync.when(
                        data: (depots) => DropdownButtonFormField<String>(
                          initialValue: _depotId,
                          decoration: const InputDecoration(
                            labelText: 'Dépôt *',
                          ),
                          items: [
                            for (final d in depots)
                              DropdownMenuItem(
                                value: d.id,
                                child: Text(d.name),
                              ),
                          ],
                          onChanged: (v) => setState(() => _depotId = v),
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
                            initialDate: _returnDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _returnDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date'),
                          child: Text(
                            '${_returnDate.day}/${_returnDate.month}/${_returnDate.year}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lignes d\'articles',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                ArticleSearchBar(onSelected: _addLine),
                const SizedBox(height: 8),
                if (_lines.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Aucune ligne. Cliquez sur + pour ajouter un article.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        Container(
                          color: AppColors.tableHeaderBg,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            children: const [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Article',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Qté',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Prix HT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'TVA%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Total HT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              SizedBox(width: 32),
                            ],
                          ),
                        ),
                        for (int i = 0; i < _lines.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '${_lines[i].articleReference}\n${_lines[i].articleDesignation}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: _lines[i].quantity,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onTapOutside: (_) => setState(() {}),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: TextField(
                                      controller: _lines[i].unitPriceHt,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      onTapOutside: (_) => setState(() {}),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      '${_lines[i].taxRatePercent.toStringAsFixed(0)}%',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      _lines[i].lineHt.toStringAsFixed(3),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 32,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: AppColors.danger,
                                    ),
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
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F5F8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total HT: ${_totalHt.toStringAsFixed(3)}'),
                      Text('Total TVA: ${_totalTva.toStringAsFixed(3)}'),
                      Text(
                        'Total TTC: ${_totalTtc.toStringAsFixed(3)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optionnel)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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

void showCustomerReturnFormDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CustomerReturnFormDialog(),
  );
}

class _CustomerReturnFormDialog extends ConsumerStatefulWidget {
  const _CustomerReturnFormDialog();

  @override
  ConsumerState<_CustomerReturnFormDialog> createState() =>
      _CustomerReturnFormDialogState();
}

class _CustomerReturnFormDialogState
    extends ConsumerState<_CustomerReturnFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();

  String? _customerId;
  String? _depotId;
  String? _showroomId;
  bool _isDepot = true;
  DateTime _returnDate = DateTime.now();
  final List<_ReturnLineEditor> _lines = [];
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    for (final l in _lines) {
      l.quantity.dispose();
      l.unitPriceHt.dispose();
    }
    super.dispose();
  }

  double get _totalHt => _lines.fold(0, (sum, l) => sum + l.lineHt);
  double get _totalTva => _lines.fold(0, (sum, l) => sum + l.lineTva);
  double get _totalTtc => _totalHt + _totalTva;

  void _addLine(Article article) {
    setState(() {
      _lines.add(
        _ReturnLineEditor(
          articleId: article.id,
          articleReference: article.reference,
          articleDesignation: article.designation,
          quantity: TextEditingController(text: '1'),
          unitPriceHt: TextEditingController(
            text: article.sellingPriceHt.toString(),
          ),
          taxRatePercent: article.taxRatePercent,
        ),
      );
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].quantity.dispose();
      _lines[index].unitPriceHt.dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      showAppSnackBar(
        context,
        'Veuillez sélectionner un client.',
        isError: true,
      );
      return;
    }
    if (_lines.isEmpty) {
      showAppSnackBar(
        context,
        'Veuillez ajouter au moins une ligne.',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final lines = _lines
          .map(
            (l) => CustomerReturnLine(
              id: '',
              returnId: '',
              articleId: l.articleId,
              quantity: l.qty,
              unitPriceHt: l.price,
              taxRatePercent: l.taxRatePercent,
              lineTotalHt: l.lineHt,
              lineTotalTva: l.lineTva,
              lineTotalTtc: l.lineTtc,
            ),
          )
          .toList();

      await ref
          .read(customerReturnRepositoryProvider)
          .createDraft(
            customerId: _customerId!,
            depotId: _isDepot ? _depotId : null,
            showroomId: _isDepot ? null : _showroomId,
            returnDate: _returnDate,
            notes: _notes.text.trim(),
            lines: lines,
          );

      ref.invalidate(customerReturnListProvider);
      if (mounted) Navigator.of(context).pop();
      if (mounted) showAppSnackBar(context, 'Retour client créé avec succès.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);
    final depotsAsync = ref.watch(activeDepotsProvider);
    final showroomsAsync = ref.watch(activeShowroomsProvider);

    return AlertDialog(
      title: const Text(
        'Nouveau retour client',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
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
                Row(
                  children: [
                    Expanded(
                      child: customersAsync.when(
                        data: (customers) => PartnerSearchField(
                          partners: customers,
                          selectedId: _customerId,
                          label: 'Client',
                          required: true,
                          onChanged: (v) => setState(() => _customerId = v),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) =>
                            const Text('Erreur chargement clients'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: depotsAsync.when(
                        data: (depots) => showroomsAsync.when(
                          data: (showrooms) => LocationSearchField(
                            depots: depots,
                            showrooms: showrooms,
                            selectedDepotId: _depotId,
                            selectedShowroomId: _showroomId,
                            label: 'Emplacement (optionnel)',
                            onChanged: (depotId, showroomId) => setState(() {
                              _depotId = depotId;
                              _showroomId = showroomId;
                              _isDepot = depotId != null || showroomId == null;
                            }),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 140,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _returnDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _returnDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date'),
                      child: Text(
                        '${_returnDate.day}/${_returnDate.month}/${_returnDate.year}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lignes d\'articles',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                ArticleSearchBar(onSelected: _addLine),
                const SizedBox(height: 8),
                if (_lines.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Aucune ligne. Cliquez sur + pour ajouter un article.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        Container(
                          color: AppColors.tableHeaderBg,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            children: const [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Article',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Qté',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Prix HT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'TVA%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Total HT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              SizedBox(width: 32),
                            ],
                          ),
                        ),
                        for (int i = 0; i < _lines.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '${_lines[i].articleReference}\n${_lines[i].articleDesignation}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: _lines[i].quantity,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onTapOutside: (_) => setState(() {}),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: TextField(
                                      controller: _lines[i].unitPriceHt,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      onTapOutside: (_) => setState(() {}),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      '${_lines[i].taxRatePercent.toStringAsFixed(0)}%',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      _lines[i].lineHt.toStringAsFixed(3),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 32,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: AppColors.danger,
                                    ),
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
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F5F8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total HT: ${_totalHt.toStringAsFixed(3)}'),
                      Text('Total TVA: ${_totalTva.toStringAsFixed(3)}'),
                      Text(
                        'Total TTC: ${_totalTtc.toStringAsFixed(3)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optionnel)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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
