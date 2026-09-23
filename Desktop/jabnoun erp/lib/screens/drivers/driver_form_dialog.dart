import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/vehicle_driver.dart';
import '../../providers/vehicle_driver_provider.dart';
import '../../widgets/common/confirm_dialog.dart';

Future<void> showDriverFormDialog(BuildContext context, WidgetRef ref, {Driver? driver}) {
  return showDialog(context: context, builder: (context) => _DriverFormDialog(driver: driver));
}

class _DriverFormDialog extends ConsumerStatefulWidget {
  final Driver? driver;
  const _DriverFormDialog({this.driver});

  @override
  ConsumerState<_DriverFormDialog> createState() => _DriverFormDialogState();
}

class _DriverFormDialogState extends ConsumerState<_DriverFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _license;
  late final TextEditingController _notes;
  bool _saving = false;

  bool get _isEdit => widget.driver != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.driver?.fullName ?? '');
    _phone = TextEditingController(text: widget.driver?.phone ?? '');
    _license = TextEditingController(text: widget.driver?.licenseNumber ?? '');
    _notes = TextEditingController(text: widget.driver?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _license.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(driverRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.driver!.id, {
          'full_name': _name.text.trim(),
          'phone': _phone.text.trim(),
          'license_number': _license.text.trim(),
          'notes': _notes.text.trim(),
        });
      } else {
        await repo.create(Driver(
          id: '',
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          licenseNumber: _license.text.trim(),
          active: true,
          notes: _notes.text.trim(),
          createdAt: DateTime.now(),
        ));
      }
      ref.invalidate(driverListProvider);
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
      title: Text(_isEdit ? 'Modifier le chauffeur' : 'Nouveau chauffeur'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est requis.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Téléphone')),
              const SizedBox(height: 12),
              TextFormField(controller: _license, decoration: const InputDecoration(labelText: 'N° permis de conduire')),
              const SizedBox(height: 12),
              TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
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
