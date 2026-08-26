import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../routes/nav_items.dart';
import '../../theme/app_colors.dart';

class AppSidebar extends ConsumerWidget {
  final String currentRoute;
  final void Function(String route) onNavigate;
  final bool collapsed;

  const AppSidebar({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permsAsync = ref.watch(currentPermissionsProvider);
    final perms = permsAsync.value ?? {};
    final isAdmin = perms.contains('*');

    return Container(
      width: collapsed ? 68 : 248,
      color: AppColors.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBrand(),
          const Divider(color: Color(0x22FFFFFF), height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final section in appNavSections)
                  _buildSection(section, isAdmin, perms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Container(
      height: 56,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: const Text('J', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          if (!collapsed) const SizedBox(width: 10),
          if (!collapsed)
            Expanded(
              child: Text(
                AppConstants.appName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(NavSection section, bool isAdmin, Set<String> perms) {
    final visibleItems = section.items.where((item) {
      if (item.permissionModule == null) return true;
      if (isAdmin) return true;
      return perms.any((p) => p.startsWith('${item.permissionModule}:'));
    }).toList();

    if (visibleItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.title.isNotEmpty && !collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                section.title,
                style: const TextStyle(
                  color: Color(0xFF7C93AB),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          for (final item in visibleItems) _buildItem(item),
        ],
      ),
    );
  }

  Widget _buildItem(NavItem item) {
    final active = currentRoute == item.route || currentRoute.startsWith('${item.route}/');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
      child: Material(
        color: active ? AppColors.sidebarActiveBg : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onNavigate(item.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(item.icon,
                    size: 18,
                    color: active ? AppColors.sidebarTextActive : AppColors.sidebarText),
                if (!collapsed) const SizedBox(width: 11),
                if (!collapsed)
                  Expanded(
                    child: Text(
                      item.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? AppColors.sidebarTextActive : AppColors.sidebarText,
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
