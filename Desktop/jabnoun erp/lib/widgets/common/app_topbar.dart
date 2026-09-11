import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';

class AppTopbar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onMenuTap;
  final List<Widget>? actions;

  const AppTopbar({super.key, required this.title, this.onMenuTap, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeAsync = ref.watch(currentEmployeeProvider);
    final authRepo = ref.watch(authRepositoryProvider);

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          if (onMenuTap != null)
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textSecondary),
              onPressed: onMenuTap,
            ),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
          const SizedBox(width: 10),
          employeeAsync.when(
            data: (employee) => PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'logout') {
                  await authRepo.signOut();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'logout', child: Text('Se déconnecter')),
              ],
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      (employee?.fullName.isNotEmpty ?? false)
                          ? employee!.fullName.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    employee?.fullName ?? '',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Icon(Icons.expand_more, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
            loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
