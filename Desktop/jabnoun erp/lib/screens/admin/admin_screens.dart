import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/audit_log.dart';
import '../../models/pos_finance.dart';
import '../../providers/depot_provider.dart';
import '../../providers/phase3_providers.dart';
import '../../providers/phase4_8_providers.dart';
import '../../providers/showroom_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import 'adjustment_line_dialog.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auditLogsProvider);
    final module = ref.watch(auditModuleFilterProvider);

    return PageScaffold(
      title: 'Journal d\'audit',
      subtitle: 'Traçabilité complète des actions',
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 250,
              height: 38,
              child: DropdownButtonFormField<String?>(
                initialValue: module,
                decoration: const InputDecoration(labelText: 'Module'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tous')),
                  DropdownMenuItem(value: 'purchases', child: Text('Achats')),
                  DropdownMenuItem(value: 'sales', child: Text('Ventes')),
                  DropdownMenuItem(
                    value: 'transfers',
                    child: Text('Transferts'),
                  ),
                  DropdownMenuItem(
                    value: 'inventories',
                    child: Text('Inventaires'),
                  ),
                  DropdownMenuItem(
                    value: 'adjustments',
                    child: Text('Ajustements'),
                  ),
                  DropdownMenuItem(value: 'pos', child: Text('POS')),
                  DropdownMenuItem(value: 'payments', child: Text('Paiements')),
                  DropdownMenuItem(value: 'expenses', child: Text('Charges')),
                ],
                onChanged: (v) =>
                    ref.read(auditModuleFilterProvider.notifier).state = v,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: async.when(
                data: (logs) => logs.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucune entrée d\'audit.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Utilisateur')),
                            DataColumn(label: Text('Action')),
                            DataColumn(label: Text('Module')),
                            DataColumn(label: Text('Objet')),
                            DataColumn(label: Text('Détails')),
                          ],
                          rows: [
                            for (final log in logs)
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      '${log.createdAt.day}/${log.createdAt.month}/${log.createdAt.year} ${log.createdAt.hour}:${log.createdAt.minute.toString().padLeft(2, '0')}',
                                    ),
                                  ),
                                  DataCell(Text(log.userFullName ?? '—')),
                                  DataCell(Text(log.action)),
                                  DataCell(Text(log.module)),
                                  DataCell(Text(log.objectLabel ?? '—')),
                                  DataCell(Text(log.details ?? '—')),
                                ],
                              ),
                          ],
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    e.toString(),
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _companyName = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _taxId = TextEditingController();
  final _currency = TextEditingController(text: 'TND');
  final _bankName = TextEditingController();
  final _bankAgency = TextEditingController();
  final _ribCodeBanque = TextEditingController();
  final _ribCodeAgence = TextEditingController();
  final _ribCompte = TextEditingController();
  final _ribCle = TextEditingController();
  final _defaultBillPlace = TextEditingController();
  bool _allowNegativeStock = false;
  bool _loading = true;
  bool _saving = false;
  String? _settingsId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _companyName.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _taxId.dispose();
    _currency.dispose();
    _bankName.dispose();
    _bankAgency.dispose();
    _ribCodeBanque.dispose();
    _ribCodeAgence.dispose();
    _ribCompte.dispose();
    _ribCle.dispose();
    _defaultBillPlace.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ref
          .read(settingsRepositoryProvider)
          .fetchSettings();
      _settingsId = settings.id;
      _companyName.text = settings.companyName;
      _address.text = settings.address ?? '';
      _phone.text = settings.phone ?? '';
      _email.text = settings.email ?? '';
      _taxId.text = settings.taxId ?? '';
      _currency.text = settings.currency;
      _allowNegativeStock = settings.allowNegativeStock;
      _bankName.text = settings.bankName ?? '';
      _bankAgency.text = settings.bankAgency ?? '';
      _ribCodeBanque.text = settings.ribCodeBanque ?? '';
      _ribCodeAgence.text = settings.ribCodeAgence ?? '';
      _ribCompte.text = settings.ribCompte ?? '';
      _ribCle.text = settings.ribCle ?? '';
      _defaultBillPlace.text = settings.defaultBillPlace ?? '';
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .updateSettings(
            CompanySettings(
              id: _settingsId!,
              companyName: _companyName.text.trim(),
              address: _address.text.trim().isEmpty
                  ? null
                  : _address.text.trim(),
              phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
              email: _email.text.trim().isEmpty ? null : _email.text.trim(),
              taxId: _taxId.text.trim().isEmpty ? null : _taxId.text.trim(),
              currency: _currency.text.trim(),
              allowNegativeStock: _allowNegativeStock,
              bankName: _bankName.text.trim(),
              bankAgency: _bankAgency.text.trim(),
              ribCodeBanque: _ribCodeBanque.text.trim(),
              ribCodeAgence: _ribCodeAgence.text.trim(),
              ribCompte: _ribCompte.text.trim(),
              ribCle: _ribCle.text.trim(),
              defaultBillPlace: _defaultBillPlace.text.trim(),
            ),
          );
      if (mounted) showAppSnackBar(context, 'Paramètres enregistrés.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PageScaffold(
        title: 'Paramètres',
        subtitle: 'Configuration de l\'entreprise',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return PageScaffold(
      title: 'Paramètres',
      subtitle: 'Configuration de l\'entreprise',
      actions: [
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
      child: ContentCard(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Informations de l\'entreprise',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _companyName,
                  decoration: const InputDecoration(
                    labelText: 'Nom de l\'entreprise *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: 'Adresse'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _taxId,
                        decoration: const InputDecoration(
                          labelText: 'Matricule fiscal',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _currency,
                        decoration: const InputDecoration(labelText: 'Devise'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Stock',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Autoriser le stock négatif'),
                  subtitle: const Text(
                    'Permet de vendre même si le stock est insuffisant',
                  ),
                  value: _allowNegativeStock,
                  onChanged: (v) => setState(() => _allowNegativeStock = v),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Domiciliation bancaire (lettres de change)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Utilisées pour pré-remplir automatiquement les lettres de change (tiré). Renseignées une seule fois.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: _bankName, decoration: const InputDecoration(labelText: 'Banque'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _bankAgency, decoration: const InputDecoration(labelText: 'Agence bancaire'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: _ribCodeBanque, decoration: const InputDecoration(labelText: 'Code banque'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _ribCodeAgence, decoration: const InputDecoration(labelText: 'Code agence'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: _ribCompte, decoration: const InputDecoration(labelText: 'N° compte'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _ribCle, decoration: const InputDecoration(labelText: 'Clé'))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: _defaultBillPlace, decoration: const InputDecoration(labelText: 'Lieu de création par défaut')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdjustmentsScreen extends ConsumerWidget {
  const AdjustmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adjustmentListProvider);
    final search = ref.watch(adjustmentSearchProvider);
    final statusFilter = ref.watch(adjustmentStatusFilterProvider);

    return PageScaffold(
      title: 'Ajustements de stock',
      subtitle: 'Corrections manuelles de stock',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _showAdjustmentDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouvel ajustement'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppSearchField(
                  hint: 'Rechercher par numéro',
                  initialValue: search,
                  onChanged: (v) =>
                      ref.read(adjustmentSearchProvider.notifier).state = v,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  height: 38,
                  child: DropdownButtonFormField<String?>(
                    initialValue: statusFilter,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tous')),
                      DropdownMenuItem(
                        value: 'brouillon',
                        child: Text('Brouillon'),
                      ),
                      DropdownMenuItem(value: 'valide', child: Text('Validé')),
                      DropdownMenuItem(value: 'annule', child: Text('Annulé')),
                    ],
                    onChanged: (v) =>
                        ref
                                .read(adjustmentStatusFilterProvider.notifier)
                                .state =
                            v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: async.when(
                data: (items) => items.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun ajustement.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('N° document')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Emplacement')),
                            DataColumn(label: Text('Motif')),
                            DataColumn(label: Text('Lignes')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final a in items)
                              DataRow(
                                cells: [
                                  DataCell(Text(a.documentNumber)),
                                  DataCell(
                                    Text(
                                      '${a.adjustmentDate.day}/${a.adjustmentDate.month}/${a.adjustmentDate.year}',
                                    ),
                                  ),
                                  DataCell(Text(a.locationLabel)),
                                  DataCell(Text(a.reason)),
                                  DataCell(Text('${a.lines.length}')),
                                  DataCell(StatusBadge.docStatus(a.status)),
                                  DataCell(_actions(context, ref, a)),
                                ],
                              ),
                          ],
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    e.toString(),
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref, StockAdjustment a) {
    return Row(
      children: [
        if (a.status == 'brouillon')
          IconButton(
            icon: const Icon(
              Icons.edit_note_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            tooltip: 'Modifier les lignes',
            onPressed: () => showAdjustmentLinesDialog(context, a),
          ),
        if (a.status == 'brouillon')
          IconButton(
            icon: const Icon(
              Icons.check_circle_outline,
              size: 18,
              color: AppColors.success,
            ),
            tooltip: 'Valider',
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'Valider l\'ajustement',
                message:
                    'Confirmer la validation de ${a.documentNumber} ? Le stock sera ajusté.',
                confirmLabel: 'Valider',
              );
              if (ok) {
                try {
                  await ref.read(adjustmentRepositoryProvider).validate(a.id);
                  ref.invalidate(adjustmentListProvider);
                  if (context.mounted) {
                    showAppSnackBar(context, 'Ajustement validé.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showAppSnackBar(context, e.toString(), isError: true);
                  }
                }
              }
            },
          ),
        if (a.status != 'annule')
          IconButton(
            icon: const Icon(
              Icons.cancel_outlined,
              size: 18,
              color: AppColors.danger,
            ),
            tooltip: 'Annuler',
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'Annuler l\'ajustement',
                message: 'Confirmer l\'annulation de ${a.documentNumber} ?',
                confirmLabel: 'Annuler',
                danger: true,
              );
              if (ok) {
                try {
                  await ref.read(adjustmentRepositoryProvider).cancel(a.id);
                  ref.invalidate(adjustmentListProvider);
                  if (context.mounted) {
                    showAppSnackBar(context, 'Ajustement annulé.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showAppSnackBar(context, e.toString(), isError: true);
                  }
                }
              }
            },
          ),
        if (a.status == 'brouillon')
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: AppColors.danger,
            ),
            tooltip: 'Supprimer',
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'Supprimer',
                message: 'Supprimer le brouillon ${a.documentNumber} ?',
                confirmLabel: 'Supprimer',
                danger: true,
              );
              if (ok) {
                try {
                  await ref.read(adjustmentRepositoryProvider).delete(a.id);
                  ref.invalidate(adjustmentListProvider);
                  if (context.mounted) {
                    showAppSnackBar(context, 'Ajustement supprimé.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showAppSnackBar(context, e.toString(), isError: true);
                  }
                }
              }
            },
          ),
      ],
    );
  }

  void _showAdjustmentDialog(BuildContext context, WidgetRef ref) {
    final reasonCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? depotId;
    String? showroomId;
    bool isDepot = true;
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final depotsAsync = ref.watch(activeDepotsProvider);
          final showroomsAsync = ref.watch(activeShowroomsProvider);
          return StatefulBuilder(
            builder: (ctx, setS) => AlertDialog(
              title: const Text(
                'Nouvel ajustement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<bool>(
                            initialValue: isDepot,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: true,
                                child: Text('Dépôt'),
                              ),
                              DropdownMenuItem(
                                value: false,
                                child: Text('Showroom'),
                              ),
                            ],
                            onChanged: (v) => setS(() {
                              isDepot = v ?? true;
                              depotId = null;
                              showroomId = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: isDepot
                              ? depotsAsync.when(
                                  data: (depots) =>
                                      DropdownButtonFormField<String?>(
                                        initialValue: depotId,
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
                                        onChanged: (v) => depotId = v,
                                      ),
                                  loading: () =>
                                      const LinearProgressIndicator(),
                                  error: (_, _) => const SizedBox.shrink(),
                                )
                              : showroomsAsync.when(
                                  data: (showrooms) =>
                                      DropdownButtonFormField<String?>(
                                        initialValue: showroomId,
                                        decoration: const InputDecoration(
                                          labelText: 'Showroom *',
                                        ),
                                        items: [
                                          for (final s in showrooms)
                                            DropdownMenuItem(
                                              value: s.id,
                                              child: Text(s.name),
                                            ),
                                        ],
                                        onChanged: (v) => showroomId = v,
                                      ),
                                  loading: () =>
                                      const LinearProgressIndicator(),
                                  error: (_, _) => const SizedBox.shrink(),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(labelText: 'Motif *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optionnel)',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Les lignes d\'articles seront ajoutées après création du brouillon.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (reasonCtrl.text.trim().isEmpty) return;
                    final id = isDepot ? depotId : showroomId;
                    if (id == null) return;
                    try {
                      await ref
                          .read(adjustmentRepositoryProvider)
                          .createDraft(
                            depotId: isDepot ? depotId : null,
                            showroomId: isDepot ? null : showroomId,
                            adjustmentDate: DateTime.now(),
                            reason: reasonCtrl.text.trim(),
                            notes: notesCtrl.text.trim(),
                            lines: [],
                          );
                      ref.invalidate(adjustmentListProvider);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (ctx.mounted) {
                        showAppSnackBar(
                          ctx,
                          'Ajustement créé (brouillon). Ajoutez les lignes depuis le détail.',
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        showAppSnackBar(ctx, e.toString(), isError: true);
                      }
                    }
                  },
                  child: const Text('Créer'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
