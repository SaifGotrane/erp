import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_sidebar.dart';
import '../../widgets/common/app_topbar.dart';

/// Coquille principale de l'application: sidebar + topbar + contenu.
/// S'adapte automatiquement en fonction de la largeur d'écran.
class AppShell extends StatefulWidget {
  final String currentRoute;
  final String title;
  final Widget child;
  final void Function(String route) onNavigate;
  final List<Widget> topbarActions;

  const AppShell({
    super.key,
    required this.currentRoute,
    required this.title,
    required this.child,
    required this.onNavigate,
    this.topbarActions = const [],
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 900;

    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.surfaceAlt,
        drawer: Drawer(
          backgroundColor: AppColors.sidebarBg,
          child: SafeArea(
            child: AppSidebar(
              currentRoute: widget.currentRoute,
              onNavigate: (route) {
                Navigator.of(context).pop();
                widget.onNavigate(route);
              },
            ),
          ),
        ),
        appBar: AppTopbar(
          title: widget.title,
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          actions: widget.topbarActions,
        ),
        body: widget.child,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Row(
        children: [
          AppSidebar(currentRoute: widget.currentRoute, onNavigate: widget.onNavigate),
          Expanded(
            child: Column(
              children: [
                AppTopbar(title: widget.title, actions: widget.topbarActions),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
