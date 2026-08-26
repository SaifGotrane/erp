import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/employee.dart';
import '../../providers/employee_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import 'employee_form_dialog.dart';
import 'employee_permissions_screen.dart';

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeeListProvider);
    final search = ref.watch(employeeSearchProvider);

    return PageScaffold(
      title: 'Employés',
      subtitle: 'Gestion des comptes employés et de leurs accès',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showEmployeeFormDialog(context, ref),
          icon: const Icon(Icons.person_add_alt_outlined, size: 18),
          label: const Text('Nouvel employé'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSearchField(
              hint: 'Rechercher employé',
              initialValue: search,
              onChanged: (v) => ref.read(employeeSearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: employeesAsync.when(
                data: (employees) => employees.isEmpty
                    ? const Center(child: Text('Aucun employé trouvé.', style: TextStyle(color: AppColors.textMuted)))
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Nom')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Rôle')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final e in employees)
                              DataRow(cells: [
                                DataCell(Text(e.fullName)),
                                DataCell(Text(e.email)),
                                DataCell(Text(e.isAdmin ? 'Administrateur' : 'Employé')),
                                DataCell(StatusBadge.active(e.active)),
                                DataCell(_rowActions(context, ref, e)),
                              ]),
                          ],
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.danger))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowActions(BuildContext context, WidgetRef ref, Employee e) {
    return Row(
      children: [
        if (!e.isAdmin)
          IconButton(
            tooltip: "Droits d'accès",
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EmployeePermissionsScreen(employee: e)),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
          onPressed: () => showEmployeeFormDialog(context, ref, employee: e),
        ),
        IconButton(
          icon: Icon(e.active ? Icons.block_outlined : Icons.check_circle_outline,
              size: 18, color: e.active ? AppColors.danger : AppColors.success),
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: e.active ? "Désactiver l'employé" : "Activer l'employé",
              message: e.active
                  ? 'Cet employé ne pourra plus se connecter. Continuer ?'
                  : 'Êtes-vous sûr de vouloir réactiver cet employé ?',
              danger: e.active,
            );
            if (confirmed) {
              await ref.read(employeeRepositoryProvider).setActive(e.id, !e.active);
              ref.invalidate(employeeListProvider);
            }
          },
        ),
      ],
    );
  }
}
