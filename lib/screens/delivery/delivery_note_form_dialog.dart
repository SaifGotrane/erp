import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/article.dart';
import '../../models/delivery_note.dart';
import '../../providers/article_provider.dart';
import '../../providers/depot_provider.dart';
import '../../providers/phase4_8_providers.dart';
import '../../providers/partner_provider.dart';
import '../../providers/showroom_provider.dart';
import '../../providers/vehicle_driver_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/article_search_bar.dart';
import '../../widgets/common/partner_search_field.dart';
import '../../widgets/common/location_search_field.dart';

class _DnLineEditor {
  String articleId;
  String articleReference;
  String articleDesignation;
  TextEditingController quantity;

  _DnLineEditor({
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    required this.quantity,
  });

  double get qty =>
      double.tryParse(quantity.text.trim().replaceAll(',', '.')) ?? 0;
}

void showDeliveryNoteFormDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeliveryNoteFormDialog(),
  );
}

class _DeliveryNoteFormDialog extends ConsumerStatefulWidget {
  const _DeliveryNoteFormDialog();

  @override
  ConsumerState<_DeliveryNoteFormDialog> createState() =>
      _DeliveryNoteFormDialogState();
}

class _DeliveryNoteFormDialogState
    extends ConsumerState<_DeliveryNoteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();

  String? _customerId;
  String? _depotId;
  String? _showroomId;
  bool _isDepot = true;
  String? _vehicleId;
  String? _driverId;
  DateTime _deliveryDate = DateTime.now();
  final List<_DnLineEditor> _lines = [];
  bool _saving = false;

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
      _lines.add(
        _DnLineEditor(
          articleId: article.id,
          articleReference: article.reference,
          articleDesignation: article.designation,
          quantity: TextEditingController(text: '1'),
        ),
      );
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
            (l) => DeliveryNoteLine(
              id: '',
              deliveryNoteId: '',
              articleId: l.articleId,
              quantity: l.qty,
            ),
          )
          .toList();

      await ref
          .read(deliveryNoteRepositoryProvider)
          .createDraft(
            customerId: _customerId!,
            depotId: _isDepot ? _depotId : null,
            showroomId: _isDepot ? null : _showroomId,
            deliveryDate: _deliveryDate,
            vehicleId: _vehicleId,
            driverId: _driverId,
            notes: _notes.text.trim(),
            lines: lines,
          );

      ref.invalidate(deliveryListProvider);
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        showAppSnackBar(context, 'Bon de livraison créé avec succès.');
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
    final vehiclesAsync = ref.watch(vehicleListProvider);
    final driversAsync = ref.watch(driverListProvider);

    return AlertDialog(
      title: const Text(
        'Nouveau bon de livraison',
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
                Row(
                  children: [
                    Expanded(
                      child: vehiclesAsync.when(
                        data: (vehicles) => DropdownButtonFormField<String?>(
                          initialValue: _vehicleId,
                          decoration: const InputDecoration(
                            labelText: 'Véhicule (optionnel)',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('—'),
                            ),
                            for (final v in vehicles)
                              DropdownMenuItem(
                                value: v.id,
                                child: Text(
                                  '${v.registrationNumber} — ${v.brand ?? ''} ${v.model ?? ''}',
                                ),
                              ),
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
                          decoration: const InputDecoration(
                            labelText: 'Chauffeur (optionnel)',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('—'),
                            ),
                            for (final d in drivers)
                              DropdownMenuItem(
                                value: d.id,
                                child: Text(d.fullName),
                              ),
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
                            initialDate: _deliveryDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _deliveryDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date'),
                          child: Text(
                            '${_deliveryDate.day}/${_deliveryDate.month}/${_deliveryDate.year}',
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
                                flex: 4,
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
                                  flex: 4,
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
