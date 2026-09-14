import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sub_client.dart';
import '../../providers/sub_client_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/scrollable_table.dart';
import '../../widgets/common/search_field.dart';

class SubClientsScreen extends ConsumerWidget {
  const SubClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subClientsAsync = ref.watch(subClientFilteredProvider);
    final search = ref.watch(subClientSearchProvider);

    return PageScaffold(
      title: 'Sous-clients',
      subtitle: 'Personnes physiques utilisées dans le fractionnement des factures',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _showFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau sous-client'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSearchField(
              hint: 'Rechercher par nom ou CIN',
              initialValue: search,
              onChanged: (v) =>
                  ref.read(subClientSearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: subClientsAsync.when(
                data: (subClients) {
                  if (subClients.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucun sous-client trouvé.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    );
                  }
                  return ScrollableTable(
                    table: DataTable(
                      columns: const [
                        DataColumn(label: Text('Nom')),
                        DataColumn(label: Text('CIN')),
                        DataColumn(label: Text('Téléphone')),
                        DataColumn(label: Text('Statut')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final sc in subClients)
                          DataRow(
                            cells: [
                              DataCell(Text(sc.name)),
                              DataCell(Text(sc.cin)),
                              DataCell(Text(sc.phone ?? '—')),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: sc.active
                                        ? AppColors.successBg
                                        : AppColors.dangerBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    sc.active ? 'Actif' : 'Désactivé',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: sc.active
                                          ? AppColors.success
                                          : AppColors.danger,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18, color: AppColors.navy),
                                      onPressed: () =>
                                          _showFormDialog(context, ref, sc),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: AppColors.danger),
                                      onPressed: () =>
                                          _deleteSubClient(context, ref, sc),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
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

  void _showFormDialog(BuildContext context, WidgetRef ref,
      [SubClient? existing]) {
    showDialog(
      context: context,
      builder: (_) => _SubClientFormDialog(existing: existing),
    );
  }

  Future<void> _deleteSubClient(
      BuildContext context, WidgetRef ref, SubClient sc) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer le sous-client',
      message: 'Supprimer "${sc.name}" (${sc.cin}) ?',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(subClientRepositoryProvider).delete(sc.id);
      ref.invalidate(subClientFilteredProvider);
      if (context.mounted) showAppSnackBar(context, 'Sous-client supprimé.');
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }
}

class _SubClientFormDialog extends ConsumerStatefulWidget {
  final SubClient? existing;
  const _SubClientFormDialog({this.existing});

  @override
  ConsumerState<_SubClientFormDialog> createState() =>
      _SubClientFormDialogState();
}

class _SubClientFormDialogState extends ConsumerState<_SubClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cinCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _cinCtrl.text = widget.existing!.cin;
      _phoneCtrl.text = widget.existing!.phone ?? '';
      _addressCtrl.text = widget.existing!.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cinCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(subClientRepositoryProvider);
      if (widget.existing == null) {
        await repo.create(
          name: _nameCtrl.text,
          cin: _cinCtrl.text,
          phone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
          address: _addressCtrl.text.isEmpty ? null : _addressCtrl.text,
        );
      } else {
        await repo.update(
          id: widget.existing!.id,
          name: _nameCtrl.text,
          cin: _cinCtrl.text,
          phone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
          address: _addressCtrl.text.isEmpty ? null : _addressCtrl.text,
        );
      }
      ref.invalidate(subClientFilteredProvider);
      if (mounted) {
        Navigator.of(context).pop();
        showAppSnackBar(context,
            widget.existing == null ? 'Sous-client créé.' : 'Sous-client modifié.');
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Nouveau sous-client' : 'Modifier le sous-client',
        style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navy),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom complet *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cinCtrl,
                decoration: const InputDecoration(
                    labelText: 'Carte d\'identité nationale (CIN) *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'CIN requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Téléphone (optionnel)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Adresse (optionnel)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save, size: 18),
          label: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
