import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/depot.dart';
import '../../providers/depot_provider.dart';
import '../../widgets/common/confirm_dialog.dart';

Future<void> showDepotFormDialog(BuildContext context, WidgetRef ref, {Depot? depot}) {
  return showDialog(
    context: context,
    builder: (context) => _DepotFormDialog(depot: depot),
  );
}

class _DepotFormDialog extends ConsumerStatefulWidget {
  final Depot? depot;
  const _DepotFormDialog({this.depot});

  @override
  ConsumerState<_DepotFormDialog> createState() => _DepotFormDialogState();
}

class _DepotFormDialogState extends ConsumerState<_DepotFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  bool _saving = false;

  bool get _isEdit => widget.depot != null;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.depot?.code ?? '');
    _name = TextEditingController(text: widget.depot?.name ?? '');
    _address = TextEditingController(text: widget.depot?.address ?? '');
    _phone = TextEditingController(text: widget.depot?.phone ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(depotRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.depot!.id, {
          'code': _code.text.trim(),
          'name': _name.text.trim(),
          'address': _address.text.trim(),
          'phone': _phone.text.trim(),
        });
      } else {
        await repo.create(Depot(
          id: '',
          code: _code.text.trim(),
          name: _name.text.trim(),
          address: _address.text.trim(),
          phone: _phone.text.trim(),
          active: true,
          createdAt: DateTime.now(),
        ));
      }
      ref.invalidate(depotListProvider);
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
      title: Text(_isEdit ? 'Modifier le dépôt' : 'Nouveau dépôt'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Code'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Le code est requis.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est requis.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Adresse'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
            ],
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
