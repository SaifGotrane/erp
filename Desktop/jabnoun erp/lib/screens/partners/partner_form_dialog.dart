import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/partner.dart';
import '../../repositories/partner_repository.dart';
import '../../widgets/common/confirm_dialog.dart';

/// Formulaire générique pour fournisseur ou client.
/// [repositoryProvider] pointe vers `supplierRepositoryProvider` ou
/// `customerRepositoryProvider`; [listProvider] est invalidé après sauvegarde.
Future<void> showPartnerFormDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required Provider<PartnerRepository> repositoryProvider,
  required ProviderBase listProvider,
  Partner? partner,
}) {
  return showDialog(
    context: context,
    builder: (context) => _PartnerFormDialog(
      title: title,
      repositoryProvider: repositoryProvider,
      listProvider: listProvider,
      partner: partner,
    ),
  );
}

class _PartnerFormDialog extends ConsumerStatefulWidget {
  final String title;
  final Provider<PartnerRepository> repositoryProvider;
  final ProviderBase listProvider;
  final Partner? partner;

  const _PartnerFormDialog({
    required this.title,
    required this.repositoryProvider,
    required this.listProvider,
    this.partner,
  });

  @override
  ConsumerState<_PartnerFormDialog> createState() => _PartnerFormDialogState();
}

class _PartnerFormDialogState extends ConsumerState<_PartnerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _contact;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  String? _governorate;
  late final TextEditingController _taxId;
  late final TextEditingController _paymentTerms;
  bool _saving = false;

  bool get _isEdit => widget.partner != null;

  @override
  void initState() {
    super.initState();
    final p = widget.partner;
    _code = TextEditingController(text: p?.code ?? '');
    _name = TextEditingController(text: p?.name ?? '');
    _company = TextEditingController(text: p?.companyName ?? '');
    _contact = TextEditingController(text: p?.contactPerson ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _address = TextEditingController(text: p?.address ?? '');
    _governorate = p?.governorate;
    _taxId = TextEditingController(text: p?.taxId ?? '');
    _paymentTerms = TextEditingController(text: p?.paymentTermsDays.toString() ?? '0');
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _company, _contact, _phone, _email, _address, _taxId, _paymentTerms]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(widget.repositoryProvider);
      final changes = {
        'code': _code.text.trim(),
        'name': _name.text.trim(),
        'company_name': _company.text.trim(),
        'contact_person': _contact.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'governorate': _governorate,
        'tax_id': _taxId.text.trim(),
        'payment_terms_days': int.tryParse(_paymentTerms.text.trim()) ?? 0,
      };
      if (_isEdit) {
        await repo.update(widget.partner!.id, changes);
      } else {
        await repo.create(Partner(
          id: '',
          code: _code.text.trim(),
          name: _name.text.trim(),
          companyName: _company.text.trim(),
          contactPerson: _contact.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          address: _address.text.trim(),
          governorate: _governorate,
          taxId: _taxId.text.trim(),
          paymentTermsDays: int.tryParse(_paymentTerms.text.trim()) ?? 0,
          active: true,
          createdAt: DateTime.now(),
        ));
      }
      ref.invalidate(widget.listProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _code,
                      decoration: const InputDecoration(labelText: 'Code'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Le code est requis.' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est requis.' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: _company, decoration: const InputDecoration(labelText: 'Société')),
                const SizedBox(height: 12),
                TextFormField(controller: _contact, decoration: const InputDecoration(labelText: 'Personne à contacter')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Téléphone'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email'))),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _governorate,
                  decoration: const InputDecoration(labelText: 'Gouvernorat'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    for (final g in tunisianGovernorates) DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) => setState(() => _governorate = v),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: _taxId, decoration: const InputDecoration(labelText: 'Matricule fiscal'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _paymentTerms,
                      decoration: const InputDecoration(labelText: 'Délai de paiement (jours)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
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
