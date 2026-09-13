import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/article.dart';
import '../../models/partner.dart';
import '../../models/sale.dart';
import '../../providers/article_provider.dart';
import '../../providers/depot_provider.dart';
import '../../providers/partner_provider.dart';
import '../../providers/phase3_providers.dart';
import '../../providers/phase4_8_providers.dart';
import '../../providers/showroom_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/article_search_bar.dart';
import '../../widgets/common/partner_search_field.dart';
import '../../widgets/common/location_search_field.dart';
import '../../services/transaction_pdf_service.dart';

class _SaleLineEditor {
  String articleId;
  String articleReference;
  String articleDesignation;
  TextEditingController quantity;
  TextEditingController unitPriceHt;
  double taxRatePercent;
  TextEditingController discountPercent;

  _SaleLineEditor({
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    required this.quantity,
    required this.unitPriceHt,
    required this.taxRatePercent,
    required this.discountPercent,
  });

  double get qty =>
      double.tryParse(quantity.text.trim().replaceAll(',', '.')) ?? 0;
  double get price =>
      double.tryParse(unitPriceHt.text.trim().replaceAll(',', '.')) ?? 0;
  double get disc =>
      double.tryParse(discountPercent.text.trim().replaceAll(',', '.')) ?? 0;
  double get lineHt => qty * price * (1 - disc / 100);
  double get lineTva => lineHt * taxRatePercent / 100;
  double get lineTtc => lineHt + lineTva;
}

void showSaleFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Sale? sale,
  bool isPos = false,
  String? posSessionId,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        SaleFormDialog(sale: sale, isPos: isPos, posSessionId: posSessionId),
  );
}

class SaleFormDialog extends ConsumerStatefulWidget {
  final Sale? sale;
  final bool isPos;
  final String? posSessionId;
  const SaleFormDialog({
    super.key,
    this.sale,
    this.isPos = false,
    this.posSessionId,
  });

  @override
  ConsumerState<SaleFormDialog> createState() => _SaleFormDialogState();
}

class _SaleFormDialogState extends ConsumerState<SaleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _discountPercent = TextEditingController(text: '0');

  String? _customerId;
  String? _depotId;
  String? _showroomId;
  bool _isDepot = true;
  String? _paymentMethodId;
  DateTime _saleDate = DateTime.now();
  final List<_SaleLineEditor> _lines = [];
  final _customerDisplayName = TextEditingController();
  static const double _stampDutyAmount = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.sale != null) {
      final s = widget.sale!;
      _customerId = s.customerId;
      _depotId = s.depotId;
      _showroomId = s.showroomId;
      _isDepot = s.depotId != null;
      _paymentMethodId = s.paymentMethodId;
      _notes.text = s.notes ?? '';
      _discountPercent.text = s.discountPercent.toString();
      _saleDate = s.saleDate;
      _customerDisplayName.text = s.customerDisplayName ?? '';
      for (final l in s.lines) {
        _lines.add(
          _SaleLineEditor(
            articleId: l.articleId,
            articleReference: l.articleReference,
            articleDesignation: l.articleDesignation,
            quantity: TextEditingController(text: l.quantity.toString()),
            unitPriceHt: TextEditingController(text: l.unitPriceHt.toString()),
            taxRatePercent: l.taxRatePercent,
            discountPercent: TextEditingController(
              text: l.discountPercent.toString(),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _discountPercent.dispose();
    _customerDisplayName.dispose();
    for (final l in _lines) {
      l.quantity.dispose();
      l.unitPriceHt.dispose();
      l.discountPercent.dispose();
    }
    super.dispose();
  }

  double get _totalHt => _lines.fold(0, (sum, l) => sum + l.lineHt);
  double get _totalTva => _lines.fold(0, (sum, l) => sum + l.lineTva);
  double get _totalTtc => _totalHt + _totalTva + _stampDutyAmount;

  bool _isParticulier(List<Partner> customers) {
    if (_customerId == null) return false;
    final match = customers.where((c) => c.id == _customerId);
    if (match.isEmpty) return false;
    return match.first.name.trim().toLowerCase() == 'particulier';
  }

  void _addLine(Article article) {
    setState(() {
      _lines.add(
        _SaleLineEditor(
          articleId: article.id,
          articleReference: article.reference,
          articleDesignation: article.designation,
          quantity: TextEditingController(text: '1'),
          unitPriceHt: TextEditingController(
            text: article.sellingPriceHt.toString(),
          ),
          taxRatePercent: article.taxRatePercent,
          discountPercent: TextEditingController(text: '0'),
        ),
      );
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
    final customers = ref.read(customerListProvider).value ?? const [];
    final isParticulier = _isParticulier(customers);
    if (isParticulier && _customerDisplayName.text.trim().isEmpty) {
      showAppSnackBar(
        context,
        'Veuillez saisir le nom à afficher sur la facture pour ce client particulier.',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final lines = _lines
          .map(
            (l) => SaleLine(
              id: '',
              saleId: '',
              articleId: l.articleId,
              quantity: l.qty,
              unitPriceHt: l.price,
              taxRatePercent: l.taxRatePercent,
              discountPercent: l.disc,
              lineTotalHt: l.lineHt,
              lineTotalTva: l.lineTva,
              lineTotalTtc: l.lineTtc,
            ),
          )
          .toList();

      final repo = ref.read(saleRepositoryProvider);

      if (widget.sale == null) {
        final created = await repo.createDraft(
          customerId: _customerId!,
          depotId: _isDepot ? _depotId : null,
          showroomId: _isDepot ? null : _showroomId,
          saleDate: _saleDate,
          paymentMethodId: _paymentMethodId,
          discountPercent:
              double.tryParse(
                _discountPercent.text.trim().replaceAll(',', '.'),
              ) ??
              0,
          isPos: widget.isPos,
          posSessionId: widget.posSessionId,
          notes: _notes.text.trim(),
          customerDisplayName: isParticulier ? _customerDisplayName.text.trim() : null,
          lines: lines,
        );
        if (widget.isPos) {
          await repo.validate(created.id);
          await ref
              .read(paymentRepositoryProvider)
              .recordPayment(
                paymentType: 'encaissement',
                partnerType: 'customer',
                partnerId: _customerId!,
                amount: _totalTtc,
                paymentMethodId: _paymentMethodId,
                saleId: created.id,
                notes: 'Encaissement comptoir',
              );
          ref.invalidate(paymentListProvider);
          try {
            await TransactionPdfService().saleDocuments(created.id);
          } catch (_) {
            if (mounted) showAppSnackBar(context, 'Vente validée, mais la génération des PDF a échoué.', isError: true);
          }
        }
      } else {
        await repo.replaceLines(widget.sale!.id, lines);
        await repo.updateDraft(widget.sale!.id, {
          'customer_id': _customerId,
          'depot_id': _isDepot ? _depotId : null,
          'showroom_id': _isDepot ? null : _showroomId,
          'payment_method_id': _paymentMethodId,
          'discount_percent':
              double.tryParse(
                _discountPercent.text.trim().replaceAll(',', '.'),
              ) ??
              0,
          'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          'customer_display_name': isParticulier ? _customerDisplayName.text.trim() : null,
          'sale_date': _saleDate.toIso8601String().split('T').first,
          'total_ht': _totalHt,
          'total_tva': _totalTva,
          'total_ttc': _totalTtc,
        });
      }

      ref.invalidate(saleListProvider);
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        showAppSnackBar(
          context,
          widget.isPos
              ? 'Vente comptoir encaissée avec succès.'
              : 'Vente enregistrée avec succès.',
        );
      }
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
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

    return AlertDialog(
      title: Text(
        widget.sale == null
            ? (widget.isPos ? 'Vente comptoir' : 'Nouvelle vente')
            : 'Modifier la vente',
        style: const TextStyle(
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
                Row(
                  children: [
                    Expanded(
                      child: paymentMethodsAsync.when(
                        data: (methods) => DropdownButtonFormField<String?>(
                          initialValue: _paymentMethodId,
                          decoration: const InputDecoration(
                            labelText: 'Méthode de paiement',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('—'),
                            ),
                            for (final m in methods)
                              DropdownMenuItem(
                                value: m.id,
                                child: Text(m.name),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _paymentMethodId = v),
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
                            initialDate: _saleDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _saleDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date'),
                          child: Text(
                            '${_saleDate.day}/${_saleDate.month}/${_saleDate.year}',
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
                                  'Remise%',
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
                                    child: TextField(
                                      controller: _lines[i].discountPercent,
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
                      Text('Droit de timbre: ${_stampDutyAmount.toStringAsFixed(3)}'),
                      Text(
                        'Total TTC: ${_totalTtc.toStringAsFixed(3)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                customersAsync.maybeWhen(
                  data: (customers) => _isParticulier(customers)
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            controller: _customerDisplayName,
                            decoration: const InputDecoration(
                              labelText: 'Nom à afficher sur la facture *',
                              helperText: 'Le client "Particulier" n\'apparaîtra pas tel quel sur la facture.',
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
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
