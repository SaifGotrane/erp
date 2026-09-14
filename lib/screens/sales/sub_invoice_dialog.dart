import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sale.dart';
import '../../models/sale_sub_invoice.dart';
import '../../models/sub_client.dart';
import '../../providers/phase4_8_providers.dart';
import '../../providers/sub_client_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';

/// Permet de fractionner une facture principale en plusieurs sous-factures
/// attribuées à des sous-clients enregistrés (personnes physiques réelles).
/// Chaque sous-facture contient des lignes d'articles entiers (quantités
/// entières), ne dépasse pas 5000 TND, et respecte la limite d'utilisation
/// par trimester (max 2 fois).
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
  SubClient? _selectedSubClient;
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  /// quantity assigned per sale line id
  final Map<String, int> _assignedQty = {};

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Remaining quantity for a sale line after existing sub-invoice allocations.
  int _remainingForLine(SaleLine line, List<SaleSubInvoice> existing) {
    final alreadyAllocated = existing.fold<int>(0, (sum, sub) {
      return sum +
          sub.lines
              .where((l) => l.saleLineId == line.id)
              .fold<int>(0, (s, l) => s + l.quantity);
    });
    return line.quantity.toInt() - alreadyAllocated;
  }

  double get _subTotal {
    double total = 0;
    for (final line in widget.sale.lines) {
      final qty = _assignedQty[line.id] ?? 0;
      if (qty > 0) {
        total += qty * line.unitPriceHt * (1 + line.taxRatePercent / 100);
      }
    }
    return total;
  }

  bool get _hasLines => _assignedQty.values.any((q) => q > 0);

  String get _trimester {
    final month = widget.sale.saleDate.month;
    if (month <= 3) return 'Q1';
    if (month <= 6) return 'Q2';
    if (month <= 9) return 'Q3';
    return 'Q4';
  }

  int get _year => widget.sale.saleDate.year;

  Future<void> _add() async {
    if (_selectedSubClient == null) {
      showAppSnackBar(context, 'Sélectionnez un sous-client.', isError: true);
      return;
    }
    if (!_hasLines) {
      showAppSnackBar(context, 'Ajoutez au moins une ligne d\'article.',
          isError: true);
      return;
    }
    if (_subTotal > 5000) {
      showAppSnackBar(
        context,
        'Le total (${_subTotal.toStringAsFixed(3)} TND) dépasse 5000 TND.',
        isError: true,
      );
      return;
    }

    final lines = <Map<String, dynamic>>[];
    for (final entry in _assignedQty.entries) {
      if (entry.value > 0) {
        lines.add({'sale_line_id': entry.key, 'quantity': entry.value});
      }
    }

    setState(() => _saving = true);
    try {
      await ref.read(saleRepositoryProvider).addSubInvoiceWithLines(
            saleId: widget.sale.id,
            subClientId: _selectedSubClient!.id,
            lines: lines,
            notes: _notesCtrl.text.trim(),
          );
      ref.invalidate(saleSubInvoicesProvider(widget.sale.id));
      ref.invalidate(
          subClientTrimesterUsageProvider((year: _year, trimester: _trimester)));
      _assignedQty.clear();
      _notesCtrl.clear();
      setState(() => _selectedSubClient = null);
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
      message:
          'Supprimer la sous-facture ${sub.documentNumber} (${sub.subClientName}) ?',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(saleRepositoryProvider).deleteSubInvoice(sub.id);
      ref.invalidate(saleSubInvoicesProvider(widget.sale.id));
      ref.invalidate(
          subClientTrimesterUsageProvider((year: _year, trimester: _trimester)));
      if (mounted) showAppSnackBar(context, 'Sous-facture supprimée.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subInvoicesAsync = ref.watch(saleSubInvoicesProvider(widget.sale.id));
    final subClientsAsync = ref.watch(subClientListProvider);
    final usageAsync = ref.watch(
      subClientTrimesterUsageProvider((year: _year, trimester: _trimester)),
    );

    return AlertDialog(
      title: Text(
        'Sous-factures — ${widget.sale.documentNumber}',
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy),
      ),
      content: SizedBox(
        width: 640,
        child: subInvoicesAsync.when(
          data: (subInvoices) {
            final allocated =
                subInvoices.fold<double>(0, (sum, s) => sum + s.amount);
            final remaining = widget.sale.totalTtc - allocated;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6)),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text(
                          'Total facture: ${widget.sale.totalTtc.toStringAsFixed(3)} TND'),
                      Text('Alloué: ${allocated.toStringAsFixed(3)} TND'),
                      Text(
                        'Restant: ${remaining.toStringAsFixed(3)} TND',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: remaining > 0.001
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (subInvoices.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(6)),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: subInvoices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = subInvoices[i];
                          final lineSummary = s.lines
                              .map((l) =>
                                  '${l.quantity}x ${l.articleReference ?? l.articleDesignation ?? ''}')
                              .join(', ');
                          return ListTile(
                            dense: true,
                            title: Text(
                                '${s.documentNumber} — ${s.subClientName}'),
                            subtitle: Text(
                              '${s.amount.toStringAsFixed(3)} TND'
                              '${lineSummary.isNotEmpty ? ' · $lineSummary' : ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.danger),
                              onPressed: () => _delete(s),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (remaining > 0.001) ...[
                  const Divider(),
                  const Text('Nouvelle sous-facture',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  // Sub-client selector
                  subClientsAsync.when(
                    data: (subClients) => usageAsync.when(
                      data: (usage) =>
                          _buildSubClientSelector(subClients, usage),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(e.toString(),
                          style: const TextStyle(color: AppColors.danger)),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(e.toString(),
                        style: const TextStyle(color: AppColors.danger)),
                  ),
                  const SizedBox(height: 12),
                  // Article lines
                  if (_selectedSubClient != null) ...[
                    const Text('Articles à inclure (quantités entières) :',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(6)),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: widget.sale.lines.length,
                        itemBuilder: (context, i) {
                          final line = widget.sale.lines[i];
                          final rem = _remainingForLine(line, subInvoices);
                          final assigned = _assignedQty[line.id] ?? 0;
                          if (rem <= 0) return const SizedBox.shrink();
                          return _buildLineRow(line, rem, assigned);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total: ${_subTotal.toStringAsFixed(3)} TND',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _subTotal > 5000
                                ? AppColors.danger
                                : AppColors.navy,
                          ),
                        ),
                        if (_subTotal > 5000)
                          const Text(
                            'Dépasse 5000 TND',
                            style: TextStyle(
                                color: AppColors.danger, fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Notes (optionnel)'),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _add,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add, size: 16),
                        label: const Text('Ajouter la sous-facture'),
                      ),
                    ),
                  ],
                ] else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text(
                      'Le montant total de la facture est entièrement réparti.',
                      style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            );
          },
          loading: () => const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator())),
          error: (e, _) =>
              Text(e.toString(), style: const TextStyle(color: AppColors.danger)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _buildSubClientSelector(
      List<SubClient> subClients, Map<String, int> usageByClient) {
    // Only sub-clients still under the trimester quota (< 2 uses) are
    // offered here — the ones already at max usage are hidden entirely.
    final eligibleClients = subClients
        .where((sc) => sc.active && (usageByClient[sc.id] ?? 0) < 2)
        .toList();
    final ineligibleCount = subClients.where((sc) => sc.active).length -
        eligibleClients.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<SubClient>(
          displayStringForOption: (sc) => '${sc.name} — ${sc.cin}',
          optionsBuilder: (textEditingValue) {
            final q = textEditingValue.text.trim().toLowerCase();
            if (q.isEmpty) return eligibleClients;
            return eligibleClients.where((sc) =>
                sc.name.toLowerCase().contains(q) ||
                sc.cin.toLowerCase().contains(q));
          },
          onSelected: (sc) => setState(() => _selectedSubClient = sc),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            final initialText = _selectedSubClient != null
                ? '${_selectedSubClient!.name} — ${_selectedSubClient!.cin}'
                : '';
            if (controller.text != initialText) {
              controller.text = initialText;
            }
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Sous-client *',
                suffixIcon: Icon(Icons.search, size: 18),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, opts) {
            final list = opts.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SizedBox(
                    width: 300,
                    child: list.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Aucun résultat.'))
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              final sc = list[i];
                              final usage = usageByClient[sc.id] ?? 0;
                              return ListTile(
                                dense: true,
                                title: Text(sc.name),
                                subtitle: Text('CIN: ${sc.cin}',
                                    style: const TextStyle(fontSize: 11)),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: usage == 0
                                        ? AppColors.successBg
                                        : AppColors.warningBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$usage/2',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: usage == 0
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                ),
                                onTap: () => onSelected(sc),
                              );
                            },
                          ),
                  ),
                ),
              ),
            );
          },
        ),
        if (eligibleClients.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Aucun sous-client disponible : tous ont atteint la limite de 2 utilisations ce trimestre.',
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          )
        else if (ineligibleCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '$ineligibleCount sous-client(s) masqué(s) (limite de 2 utilisations/trimestre atteinte).',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        if (_selectedSubClient != null &&
            (usageByClient[_selectedSubClient!.id] ?? 0) == 1)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'ℹ Ce sous-client a déjà été utilisé 1 fois ce trimestre (dernière utilisation autorisée).',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildLineRow(SaleLine line, int remaining, int assigned) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.articleReference,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  '${line.articleDesignation} — ${line.unitPriceHt.toStringAsFixed(3)} TND/u',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('Dispo: $remaining',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextFormField(
              initialValue: assigned > 0 ? assigned.toString() : '',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                hintText: '0',
              ),
              onChanged: (v) {
                final qty = int.tryParse(v) ?? 0;
                setState(() {
                  if (qty > 0 && qty <= remaining) {
                    _assignedQty[line.id] = qty;
                  } else if (qty <= 0) {
                    _assignedQty.remove(line.id);
                  } else {
                    _assignedQty[line.id] = remaining;
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
