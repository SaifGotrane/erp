import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/article_provider.dart';
import '../../providers/partner_provider.dart';
import '../../providers/sav_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/partner_search_field.dart';

void showSavTicketFormDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _SavTicketFormDialog(),
  );
}

class _SavTicketFormDialog extends ConsumerStatefulWidget {
  const _SavTicketFormDialog();

  @override
  ConsumerState<_SavTicketFormDialog> createState() => _SavTicketFormDialogState();
}

class _SavTicketFormDialogState extends ConsumerState<_SavTicketFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _issueCtrl = TextEditingController();
  String? _customerId;
  String? _articleId;
  String? _supplierId;
  DateTime _reclamationDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _issueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null || _articleId == null) {
      showAppSnackBar(context, 'Veuillez sélectionner un client et un article.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(savRepositoryProvider).create(
            customerId: _customerId!,
            articleId: _articleId!,
            supplierId: _supplierId,
            issueDescription: _issueCtrl.text.trim(),
            reclamationDate: _reclamationDate,
          );
      ref.invalidate(savTicketListProvider);
      if (mounted) Navigator.of(context).pop();
      if (mounted) showAppSnackBar(context, 'Ticket SAV créé avec succès.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);
    final articlesAsync = ref.watch(articleListProvider);
    final suppliersAsync = ref.watch(supplierListProvider);

    return AlertDialog(
      title: const Text('Nouveau ticket SAV', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                customersAsync.when(
                  data: (customers) => PartnerSearchField(
                    partners: customers,
                    selectedId: _customerId,
                    label: 'Client',
                    required: true,
                    onChanged: (v) => setState(() => _customerId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text('Erreur chargement clients'),
                ),
                const SizedBox(height: 12),
                articlesAsync.when(
                  data: (articles) => DropdownButtonFormField<String>(
                    initialValue: _articleId,
                    decoration: const InputDecoration(labelText: 'Article *'),
                    items: [for (final a in articles) DropdownMenuItem(value: a.id, child: Text('${a.reference} — ${a.designation}'))],
                    onChanged: (v) => setState(() => _articleId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text('Erreur chargement articles'),
                ),
                const SizedBox(height: 12),
                suppliersAsync.when(
                  data: (suppliers) => PartnerSearchField(
                    partners: suppliers,
                    selectedId: _supplierId,
                    label: 'Fournisseur cible (optionnel)',
                    onChanged: (v) => setState(() => _supplierId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _reclamationDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _reclamationDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date de réclamation'),
                    child: Text('${_reclamationDate.day}/${_reclamationDate.month}/${_reclamationDate.year}'),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _issueCtrl,
                  decoration: const InputDecoration(labelText: 'Description du problème *'),
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'La description est requise.' : null,
                ),
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
              : const Text('Créer'),
        ),
      ],
    );
  }
}
