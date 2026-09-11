import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/article.dart';
import '../../models/stock_transfer.dart';
import '../../providers/article_provider.dart';
import '../../providers/depot_provider.dart';
import '../../providers/phase3_providers.dart';
import '../../providers/showroom_provider.dart';
import '../../providers/vehicle_driver_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/article_search_bar.dart';

class _TransferLineEditor {
  String articleId;
  String articleReference;
  String articleDesignation;
  TextEditingController quantity;

  _TransferLineEditor({
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    required this.quantity,
  });

  double get qty => double.tryParse(quantity.text.trim().replaceAll(',', '.')) ?? 0;
}

void showTransferFormDialog(BuildContext context, WidgetRef ref, {StockTransfer? transfer}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => TransferFormDialog(transfer: transfer),
  );
}

class TransferFormDialog extends ConsumerStatefulWidget {
  final StockTransfer? transfer;
  const TransferFormDialog({super.key, this.transfer});

  @override
  ConsumerState<TransferFormDialog> createState() => _TransferFormDialogState();
}

class _TransferFormDialogState extends ConsumerState<TransferFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();

  String? _sourceDepotId;
  String? _sourceShowroomId;
  String? _destDepotId;
  String? _destShowroomId;
  String? _vehicleId;
  String? _driverId;
  DateTime _transferDate = DateTime.now();
  final List<_TransferLineEditor> _lines = [];
  bool _saving = false;

  bool _sourceIsDepot = true;
  bool _destIsDepot = true;

  @override
  void initState() {
    super.initState();
    if (widget.transfer != null) {
      final t = widget.transfer!;
      _sourceDepotId = t.sourceDepotId;
      _sourceShowroomId = t.sourceShowroomId;
      _destDepotId = t.destinationDepotId;
      _destShowroomId = t.destinationShowroomId;
      _sourceIsDepot = t.sourceDepotId != null;
      _destIsDepot = t.destinationDepotId != null;
      _vehicleId = t.vehicleId;
      _driverId = t.driverId;
      _notes.text = t.notes ?? '';
      _transferDate = t.transferDate;
      for (final l in t.lines) {
        _lines.add(_TransferLineEditor(
          articleId: l.articleId,
          articleReference: l.articleReference,
          articleDesignation: l.articleDesignation,
          quantity: TextEditingController(text: l.quantity.toString()),
        ));
      }
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final l in _lines) {
      l.quantity.dispose();
    }
    super.dispose();
  }

  void _addLine(Article article) {
    setState(() {
      _lines.add(_TransferLineEditor(
        articleId: article.id,
        articleReference: article.reference,
        articleDesignation: article.designation,
        quantity: TextEditingController(text: '1'),
      ));
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].quantity.dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final sourceId = _sourceIsDepot ? _sourceDepotId : _sourceShowroomId;
    final destId = _destIsDepot ? _destDepotId : _destShowroomId;

    if (sourceId == null || destId == null) {
      showAppSnackBar(context, 'Veuillez sélectionner la source et la destination.', isError: true);
      return;
    }
    if (_lines.isEmpty) {
      showAppSnackBar(context, 'Veuillez ajouter au moins une ligne.', isError: true);
      return;
    }
    if (_sourceIsDepot == _destIsDepot && sourceId == destId) {
      showAppSnackBar(context, 'La source et la destination doivent être différentes.', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final lines = _lines
          .map((l) => StockTransferLine(
                id: '',
                transferId: '',
                articleId: l.articleId,
                quantity: l.qty,
              ))
          .toList();

      final repo = ref.read(transferRepositoryProvider);

      if (widget.transfer == null) {
        await repo.createDraft(
          sourceDepotId: _sourceIsDepot ? _sourceDepotId : null,
          sourceShowroomId: _sourceIsDepot ? null : _sourceShowroomId,
          destinationDepotId: _destIsDepot ? _destDepotId : null,
          destinationShowroomId: _destIsDepot ? null : _destShowroomId,
          transferDate: _transferDate,
          vehicleId: _vehicleId,
          driverId: _driverId,
          notes: _notes.text.trim(),
          lines: lines,
        );
      } else {
        await repo.cancel(widget.transfer!.id);
        await repo.createDraft(
          sourceDepotId: _sourceIsDepot ? _sourceDepotId : null,
          sourceShowroomId: _sourceIsDepot ? null : _sourceShowroomId,
          destinationDepotId: _destIsDepot ? _destDepotId : null,
          destinationShowroomId: _destIsDepot ? null : _destShowroomId,
          transferDate: _transferDate,
          vehicleId: _vehicleId,
          driverId: _driverId,
          notes: _notes.text.trim(),
          lines: lines,
        );
      }

      ref.invalidate(transferListProvider);
      if (mounted) Navigator.of(context).pop();
      if (mounted) showAppSnackBar(context, 'Transfert enregistré avec succès.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final depotsAsync = ref.watch(activeDepotsProvider);
    final showroomsAsync = ref.watch(activeShowroomsProvider);
    final vehiclesAsync = ref.watch(activeVehiclesProvider);
    final driversAsync = ref.watch(activeDriversProvider);

    return AlertDialog(
      title: Text(widget.transfer == null ? 'Nouveau transfert' : 'Modifier le transfert',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navy)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.75,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<bool>(
                      initialValue: _sourceIsDepot,
                      decoration: const InputDecoration(labelText: 'Type source'),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Dépôt')),
                        DropdownMenuItem(value: false, child: Text('Showroom')),
                      ],
                      onChanged: (v) => setState(() {
                        _sourceIsDepot = v ?? true;
                        _sourceDepotId = null;
                        _sourceShowroomId = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sourceIsDepot
                        ? depotsAsync.when(
                            data: (depots) => DropdownButtonFormField<String>(
                              initialValue: _sourceDepotId,
                              decoration: const InputDecoration(labelText: 'Dépôt source *'),
                              items: [for (final d in depots) DropdownMenuItem(value: d.id, child: Text(d.name))],
                              onChanged: (v) => setState(() => _sourceDepotId = v),
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => const SizedBox.shrink(),
                          )
                        : showroomsAsync.when(
                            data: (showrooms) => DropdownButtonFormField<String>(
                              initialValue: _sourceShowroomId,
                              decoration: const InputDecoration(labelText: 'Showroom source *'),
                              items: [for (final s in showrooms) DropdownMenuItem(value: s.id, child: Text(s.name))],
                              onChanged: (v) => setState(() => _sourceShowroomId = v),
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<bool>(
                      initialValue: _destIsDepot,
                      decoration: const InputDecoration(labelText: 'Type destination'),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Dépôt')),
                        DropdownMenuItem(value: false, child: Text('Showroom')),
                      ],
                      onChanged: (v) => setState(() {
                        _destIsDepot = v ?? true;
                        _destDepotId = null;
                        _destShowroomId = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _destIsDepot
                        ? depotsAsync.when(
                            data: (depots) => DropdownButtonFormField<String>(
                              initialValue: _destDepotId,
                              decoration: const InputDecoration(labelText: 'Dépôt destination *'),
                              items: [for (final d in depots) DropdownMenuItem(value: d.id, child: Text(d.name))],
                              onChanged: (v) => setState(() => _destDepotId = v),
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => const SizedBox.shrink(),
                          )
                        : showroomsAsync.when(
                            data: (showrooms) => DropdownButtonFormField<String>(
                              initialValue: _destShowroomId,
                              decoration: const InputDecoration(labelText: 'Showroom destination *'),
                              items: [for (final s in showrooms) DropdownMenuItem(value: s.id, child: Text(s.name))],
                              onChanged: (v) => setState(() => _destShowroomId = v),
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: vehiclesAsync.when(
                      data: (vehicles) => DropdownButtonFormField<String?>(
                        initialValue: _vehicleId,
                        decoration: const InputDecoration(labelText: 'Véhicule (optionnel)'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Aucun')),
                          for (final v in vehicles) DropdownMenuItem(value: v.id, child: Text('${v.registrationNumber} — ${v.brand ?? ''} ${v.model ?? ''}')),
                        ],
                        onChanged: (v) => setState(() => _vehicleId = v),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: driversAsync.when(
                      data: (drivers) => DropdownButtonFormField<String?>(
                        initialValue: _driverId,
                        decoration: const InputDecoration(labelText: 'Chauffeur (optionnel)'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Aucun')),
                          for (final d in drivers) DropdownMenuItem(value: d.id, child: Text(d.fullName)),
                        ],
                        onChanged: (v) => setState(() => _driverId = v),
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
                          initialDate: _transferDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _transferDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date'),
                        child: Text('${_transferDate.day}/${_transferDate.month}/${_transferDate.year}'),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Articles à transférer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.navy)),
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
                              Expanded(flex: 4, child: Text('Article', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Text('Quantité', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                              SizedBox(width: 32),
                            ],
                          ),
                        ),
                        for (int i = 0; i < _lines.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Expanded(flex: 4, child: Text('${_lines[i].articleReference}\n${_lines[i].articleDesignation}', style: const TextStyle(fontSize: 12))),
                                Expanded(flex: 2, child: TextField(controller: _lines[i].quantity, style: const TextStyle(fontSize: 12), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()))),
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
