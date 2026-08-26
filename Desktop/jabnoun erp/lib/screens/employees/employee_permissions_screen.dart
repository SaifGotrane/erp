import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/permission_labels.dart';
import '../../models/employee.dart';
import '../../providers/employee_provider.dart';
import '../../repositories/employee_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';

/// Matrice de gestion des droits d'accès pour un employé donné.
/// Voir cahier des charges §5 (exemple: Articles -> Voir/Ajouter/Modifier/Supprimer).
class EmployeePermissionsScreen extends ConsumerStatefulWidget {
  final Employee employee;
  const EmployeePermissionsScreen({super.key, required this.employee});

  @override
  ConsumerState<EmployeePermissionsScreen> createState() => _EmployeePermissionsScreenState();
}

class _EmployeePermissionsScreenState extends ConsumerState<EmployeePermissionsScreen> {
  Map<String, bool>? _state; // key = "module:action"
  bool _saving = false;
  bool _initialized = false;

  void _initFromExisting(List<EmployeePermission> existing) {
    if (_initialized) return;
    _initialized = true;
    final matrix = EmployeeRepository.emptyPermissionMatrix(widget.employee.id);
    final map = <String, bool>{for (final p in matrix) '${p.module}:${p.action}': false};
    for (final p in existing) {
      map['${p.module}:${p.action}'] = p.allowed;
    }
    _state = map;
  }

  Future<void> _save() async {
    if (_state == null) return;
    setState(() => _saving = true);
    try {
      final permissions = _state!.entries.map((e) {
        final parts = e.key.split(':');
        return EmployeePermission(employeeId: widget.employee.id, module: parts[0], action: parts[1], allowed: e.value);
      }).toList();
      await ref.read(employeeRepositoryProvider).savePermissions(widget.employee.id, permissions);
      ref.invalidate(employeePermissionsProvider(widget.employee.id));
      if (mounted) showAppSnackBar(context, 'Droits d\'accès enregistrés.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permsAsync = ref.watch(employeePermissionsProvider(widget.employee.id));

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(title: Text("Droits d'accès — ${widget.employee.fullName}")),
      body: permsAsync.when(
        data: (existing) {
          _initFromExisting(existing);
          return PageScaffold(
            title: "Droits d'accès",
            subtitle: 'Sélectionnez précisément les actions autorisées pour cet employé.',
            actions: [
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Enregistrer'),
              ),
            ],
            child: ListView(
              children: [
                for (final module in PermissionModule.all) _buildModuleCard(module),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.danger))),
      ),
    );
  }

  Widget _buildModuleCard(String module) {
    final actions = _state!.keys.where((k) => k.startsWith('$module:')).map((k) => k.split(':')[1]).toList();
    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(PermissionLabels.module(module),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 20,
            runSpacing: 6,
            children: [
              for (final action in actions)
                _CheckboxTile(
                  label: PermissionLabels.action(action),
                  value: _state!['$module:$action']!,
                  onChanged: (v) => setState(() => _state!['$module:$action'] = v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckboxTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CheckboxTile({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), visualDensity: VisualDensity.compact),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
