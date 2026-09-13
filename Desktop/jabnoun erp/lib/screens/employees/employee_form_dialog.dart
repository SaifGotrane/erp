import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/employee.dart';
import '../../providers/depot_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/showroom_provider.dart';
import '../../widgets/common/confirm_dialog.dart';

Future<void> showEmployeeFormDialog(BuildContext context, WidgetRef ref, {Employee? employee}) {
  return showDialog(context: context, builder: (context) => _EmployeeFormDialog(employee: employee));
}

class _EmployeeFormDialog extends ConsumerStatefulWidget {
  final Employee? employee;
  const _EmployeeFormDialog({this.employee});

  @override
  ConsumerState<_EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends ConsumerState<_EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  final _password = TextEditingController();
  EmployeeRole _role = EmployeeRole.employee;
  String? _depotId;
  String? _showroomId;
  bool _saving = false;

  bool get _isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _fullName = TextEditingController(text: e?.fullName ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _role = e?.role ?? EmployeeRole.employee;
    _depotId = e?.depotId;
    _showroomId = e?.showroomId;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(employeeRepositoryProvider);
      if (_isEdit) {
        await repo.updateEmployee(widget.employee!.id, {
          'full_name': _fullName.text.trim(),
          'phone': _phone.text.trim(),
          'role': employeeRoleToString(_role),
          'depot_id': _depotId,
          'showroom_id': _showroomId,
        });
      } else {
        await repo.createEmployee(
          fullName: _fullName.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          role: _role,
          phone: _phone.text.trim(),
          depotId: _depotId,
          showroomId: _showroomId,
        );
      }
      ref.invalidate(employeeListProvider);
      if (mounted) Navigator.of(context).pop();
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
      title: Text(_isEdit ? "Modifier l'employé" : 'Nouvel employé'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _fullName,
                  decoration: const InputDecoration(labelText: 'Nom complet'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est requis.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  enabled: !_isEdit,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "L'email est requis." : null,
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mot de passe initial'),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Le mot de passe doit contenir au moins 6 caractères.' : null,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Téléphone')),
                const SizedBox(height: 12),
                DropdownButtonFormField<EmployeeRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: const [
                    DropdownMenuItem(value: EmployeeRole.employee, child: Text('Employé')),
                    DropdownMenuItem(value: EmployeeRole.admin, child: Text('Administrateur')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? EmployeeRole.employee),
                ),
                const SizedBox(height: 12),
                depotsAsync.when(
                  data: (depots) => DropdownButtonFormField<String>(
                    initialValue: _depotId,
                    decoration: const InputDecoration(labelText: 'Dépôt affecté (optionnel)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Aucun')),
                      for (final d in depots) DropdownMenuItem(value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (v) => setState(() => _depotId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                showroomsAsync.when(
                  data: (showrooms) => DropdownButtonFormField<String>(
                    initialValue: _showroomId,
                    decoration: const InputDecoration(labelText: 'Showroom affecté (optionnel)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Aucun')),
                      for (final s in showrooms) DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setState(() => _showroomId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
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
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
