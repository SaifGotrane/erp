import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory.dart';
import '../../providers/depot_provider.dart';
import '../../providers/phase3_providers.dart';
import '../../providers/showroom_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';

class _InvLineEditor {
  final String articleId;
  final String articleReference;
  final String articleDesignation;
  final double theoreticalQuantity;
  TextEditingController realQuantity;

  _InvLineEditor({
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    required this.theoreticalQuantity,
    required this.realQuantity,
  });

  double get realQty => double.tryParse(realQuantity.text.trim().replaceAll(',', '.')) ?? 0;
  double get gap => realQty - theoreticalQuantity;
}

void showInventoryFormDialog(BuildContext context, WidgetRef ref, {Inventory? inventory}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => InventoryFormDialog(inventory: inventory),
  );
}

class InventoryFormDialog extends ConsumerStatefulWidget {
  final Inventory? inventory;
  const InventoryFormDialog({super.key, this.inventory});

  @override
  ConsumerState<InventoryFormDialog> createState() => _InventoryFormDialogState();
}

class _InventoryFormDialogState extends ConsumerState<InventoryFormDialog> {
  final _notes = TextEditingController();
  String? _depotId;
  String? _showroomId;
  bool _isDepot = true;
  DateTime _inventoryDate = DateTime.now();
  List<_InvLineEditor> _lines = [];
  bool _saving = false;
  bool _loadingStock = false;

  @override
  void initState() {
    super.initState();
    if (widget.inventory != null) {
      final inv = widget.inventory!;
      _depotId = inv.depotId;
      _showroomId = inv.showroomId;
      _isDepot = inv.depotId != null;
      _notes.text = inv.notes ?? '';
      _inventoryDate = inv.inventoryDate;
      _lines = inv.lines
          .map((l) => _InvLineEditor(
                articleId: l.articleId,
                articleReference: l.articleReference,
                articleDesignation: l.articleDesignation,
                theoreticalQuantity: l.theoreticalQuantity,
                realQuantity: TextEditingController(text: l.realQuantity.toString()),
              ))
          .toList();
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final l in _lines) {
      l.realQuantity.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTheoreticalStock() async {
    final id = _isDepot ? _depotId : _showroomId;
    if (id == null) return;

    setState(() => _loadingStock = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final stock = await repo.fetchTheoreticalStock(
        depotId: _isDepot ? _depotId : null,
        showroomId: _isDepot ? null : _showroomId,
      );

      for (final l in _lines) {
        l.realQuantity.dispose();
      }

      setState(() {
        _lines = stock
            .map((s) => _InvLineEditor(
                  articleId: s['article_id'] as String,
                  articleReference: s['reference'] as String? ?? '',
                  articleDesignation: s['designation'] as String? ?? '',
                  theoreticalQuantity: (s['theoretical_quantity'] as num?)?.toDouble() ?? 0,
                  realQuantity: TextEditingController(text: ((s['theoretical_quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)),
                ))
            .toList();
      });
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loadingStock = false);
    }
  }

  Future<void> _save() async {
    final id = _isDepot ? _depotId : _showroomId;
    if (id == null) {
      showAppSnackBar(context, 'Veuillez sélectionner un emplacement.', isError: true);
      return;
    }
    if (_lines.isEmpty) {
      showAppSnackBar(context, 'Aucun article à inventorier. Chargez le stock théorique.', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final lines = _lines
          .map((l) => InventoryLine(
                id: '',
                inventoryId: '',
                articleId: l.articleId,
                theoreticalQuantity: l.theoreticalQuantity,
                realQuantity: l.realQty,
                gap: l.gap,
              ))
          .toList();

      final repo = ref.read(inventoryRepositoryProvider);

      if (widget.inventory == null) {
        await repo.createDraft(
          depotId: _isDepot ? _depotId : null,
          showroomId: _isDepot ? null : _showroomId,
          inventoryDate: _inventoryDate,
          notes: _notes.text.trim(),
          lines: lines,
        );
      } else {
        await repo.updateLines(widget.inventory!.id, lines);
        await repo.updateDraft(widget.inventory!.id, {
          'depot_id': _isDepot ? _depotId : null,
          'showroom_id': _isDepot ? null : _showroomId,
          'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          'inventory_date': _inventoryDate.toIso8601String().split('T').first,
        });
      }

      ref.invalidate(inventoryListProvider);
      if (mounted) Navigator.of(context).pop();
      if (mounted) showAppSnackBar(context, 'Inventaire enregistré avec succès.');
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

    return AlertDialog(
      title: Text(widget.inventory == null ? 'Nouvel inventaire' : 'Modifier l\'inventaire',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navy)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.8,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<bool>(
                    initialValue: _isDepot,
                    decoration: const InputDecoration(labelText: 'Type d\'emplacement'),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Dépôt')),
                      DropdownMenuItem(value: false, child: Text('Showroom')),
                    ],
                    onChanged: (v) => setState(() {
                      _isDepot = v ?? true;
                      _depotId = null;
                      _showroomId = null;
                      _lines = [];
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isDepot
                      ? depotsAsync.when(
                          data: (depots) => DropdownButtonFormField<String>(
                            initialValue: _depotId,
                            decoration: const InputDecoration(labelText: 'Dépôt *'),
                            items: [for (final d in depots) DropdownMenuItem(value: d.id, child: Text(d.name))],
                            onChanged: (v) => setState(() => _depotId = v),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) => const SizedBox.shrink(),
                        )
                      : showroomsAsync.when(
                          data: (showrooms) => DropdownButtonFormField<String>(
                            initialValue: _showroomId,
                            decoration: const InputDecoration(labelText: 'Showroom *'),
                            items: [for (final s in showrooms) DropdownMenuItem(value: s.id, child: Text(s.name))],
                            onChanged: (v) => setState(() => _showroomId = v),
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
                        initialDate: _inventoryDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _inventoryDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date'),
                      child: Text('${_inventoryDate.day}/${_inventoryDate.month}/${_inventoryDate.year}'),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: (_isDepot ? _depotId : _showroomId) == null || _loadingStock
                      ? null
                      : _loadTheoreticalStock,
                  icon: _loadingStock
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download, size: 18),
                  label: const Text('Charger le stock théorique'),
                ),
              ),
              const SizedBox(height: 12),
              if (_lines.isNotEmpty) ...[
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
                            Expanded(flex: 2, child: Text('Théorique', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                            Expanded(flex: 2, child: Text('Réel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                            Expanded(flex: 2, child: Text('Écart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                          ],
                        ),
                      ),
                      for (int i = 0; i < _lines.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              Expanded(flex: 4, child: Text('${_lines[i].articleReference}\n${_lines[i].articleDesignation}', style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 2, child: Text(_lines[i].theoreticalQuantity.toStringAsFixed(3), style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 2, child: TextField(controller: _lines[i].realQuantity, style: const TextStyle(fontSize: 12), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), onTapOutside: (_) => setState(() {}))),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    (_lines[i].gap >= 0 ? '+' : '') + _lines[i].gap.toStringAsFixed(3),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _lines[i].gap == 0 ? AppColors.textSecondary : (_lines[i].gap > 0 ? AppColors.success : AppColors.danger),
                                    ),
                                  ),
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
              ] else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                  child: const Text('Sélectionnez un emplacement puis cliquez sur « Charger le stock théorique ».',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _saving || _lines.isEmpty ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
