import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/vehicle_driver.dart';
import '../../providers/vehicle_driver_provider.dart';
import '../../widgets/common/confirm_dialog.dart';

Future<void> showVehicleFormDialog(BuildContext context, WidgetRef ref, {Vehicle? vehicle}) {
  return showDialog(context: context, builder: (context) => _VehicleFormDialog(vehicle: vehicle));
}

class _VehicleFormDialog extends ConsumerStatefulWidget {
  final Vehicle? vehicle;
  const _VehicleFormDialog({this.vehicle});

  @override
  ConsumerState<_VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends ConsumerState<_VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reg;
  late final TextEditingController _type;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _capacity;
  late final TextEditingController _notes;
  String? _driverId;
  bool _saving = false;

  bool get _isEdit => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    _reg = TextEditingController(text: widget.vehicle?.registrationNumber ?? '');
    _type = TextEditingController(text: widget.vehicle?.vehicleType ?? '');
    _brand = TextEditingController(text: widget.vehicle?.brand ?? '');
    _model = TextEditingController(text: widget.vehicle?.model ?? '');
    _capacity = TextEditingController(text: widget.vehicle?.capacity?.toString() ?? '');
    _notes = TextEditingController(text: widget.vehicle?.notes ?? '');
    _driverId = widget.vehicle?.driverId;
  }

  @override
  void dispose() {
    _reg.dispose();
    _type.dispose();
    _brand.dispose();
    _model.dispose();
    _capacity.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(vehicleRepositoryProvider);
      final changes = {
        'registration_number': _reg.text.trim(),
        'vehicle_type': _type.text.trim(),
        'brand': _brand.text.trim(),
        'model': _model.text.trim(),
        'capacity': double.tryParse(_capacity.text.trim()),
        'driver_id': _driverId,
        'notes': _notes.text.trim(),
      };
      if (_isEdit) {
        await repo.update(widget.vehicle!.id, changes);
      } else {
        await repo.create(Vehicle(
          id: '',
          registrationNumber: _reg.text.trim(),
          vehicleType: _type.text.trim(),
          brand: _brand.text.trim(),
          model: _model.text.trim(),
          capacity: double.tryParse(_capacity.text.trim()),
          driverId: _driverId,
          active: true,
          notes: _notes.text.trim(),
          createdAt: DateTime.now(),
        ));
      }
      ref.invalidate(vehicleListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(activeDriversProvider);
    return AlertDialog(
      title: Text(_isEdit ? 'Modifier le véhicule' : 'Nouveau véhicule'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _reg,
                  decoration: const InputDecoration(labelText: 'Immatriculation'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "L'immatriculation est requise." : null,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _type, decoration: const InputDecoration(labelText: 'Type de véhicule')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: _brand, decoration: const InputDecoration(labelText: 'Marque'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _model, decoration: const InputDecoration(labelText: 'Modèle'))),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _capacity,
                  decoration: const InputDecoration(labelText: 'Capacité'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                driversAsync.when(
                  data: (drivers) => DropdownButtonFormField<String>(
                    initialValue: _driverId,
                    decoration: const InputDecoration(labelText: 'Chauffeur assigné'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Aucun')),
                      for (final d in drivers) DropdownMenuItem(value: d.id, child: Text(d.fullName)),
                    ],
                    onChanged: (v) => setState(() => _driverId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
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
