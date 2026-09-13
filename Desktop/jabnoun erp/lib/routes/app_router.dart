import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/articles/articles_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/categories/categories_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/delivery/delivery_notes_screen.dart';
import '../screens/depots/depots_screen.dart';
import '../screens/drivers/drivers_screen.dart';
import '../screens/employees/employees_screen.dart';
import '../screens/admin/admin_screens.dart';
import '../screens/finance/finance_screens.dart';
import '../screens/finance/bills_of_exchange_screen.dart';
import '../screens/inventories/inventories_screen.dart';
import '../screens/partners/customers_screen.dart';
import '../screens/partners/suppliers_screen.dart';
import '../screens/pos/pos_screen.dart';
import '../screens/pos/pos_sale_screen.dart';
import '../screens/purchases/purchases_screen.dart';
import '../screens/reports/report_screens.dart';
import '../screens/returns/returns_screen.dart';
import '../screens/sales/sales_screen.dart';
import '../screens/sav/sav_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/showrooms/showrooms_screen.dart';
import '../screens/stock/stock_movements_screen.dart';
import '../screens/stock/stock_screen.dart';
import '../screens/transfers/transfers_screen.dart';
import '../screens/vehicles/vehicles_screen.dart';
import 'nav_items.dart';
import 'router_refresh_notifier.dart';

/// Titres associés à chaque route pour la barre supérieure.
String _titleForRoute(String route) {
  for (final section in appNavSections) {
    for (final item in section.items) {
      if (item.route == route) return item.label;
    }
  }
  return 'Jabnoun ERP';
}

String? _permissionModuleForRoute(String route) {
  for (final section in appNavSections) {
    for (final item in section.items) {
      if (item.route == route) return item.permissionModule;
    }
  }
  return null;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final routerRefresh = RouterRefreshNotifier(authRepo.onAuthStateChange);
  ref.onDispose(routerRefresh.dispose);

  ref.listen(currentPermissionsProvider, (previous, next) {
    routerRefresh.refresh();
  });

  Widget permissionsScreen(String route, String description) =>
      const EmployeesScreen();

  // Surveille le profil employé : si la session est valide mais l'employé
  // est introuvable ou désactivé, on déconnecte automatiquement l'utilisateur.
  ref.listen(currentEmployeeProvider, (previous, next) {
    next.whenData((employee) async {
      if (authRepo.currentSession != null &&
          (employee == null || !employee.active)) {
        await authRepo.signOut();
      }
    });
  });

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: routerRefresh,
    redirect: (context, state) {
      final loggedIn = authRepo.currentSession != null;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/dashboard';

      final permissionModule = _permissionModuleForRoute(state.matchedLocation);
      if (permissionModule == null) return null;

      final employee = ref.read(currentEmployeeProvider).value;
      if (employee == null ||
          !employee.active ||
          employee.id != authRepo.currentUser?.id) {
        return state.matchedLocation == '/dashboard' ? null : '/dashboard';
      }

      final permissions = ref.read(currentPermissionsProvider).value;
      if (permissions == null) {
        return state.matchedLocation == '/dashboard' ? null : '/dashboard';
      }

      final authorized =
          permissions.contains('*') ||
          permissions.any(
            (permission) => permission.startsWith('$permissionModule:'),
          );
      if (!authorized) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) {
          final route = state.matchedLocation;
          return AppShell(
            currentRoute: route,
            title: _titleForRoute(route),
            onNavigate: (r) => context.go(r),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/articles',
            builder: (context, state) => const ArticlesScreen(),
          ),
          GoRoute(
            path: '/categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
          GoRoute(
            path: '/depots',
            builder: (context, state) => const DepotsScreen(),
          ),
          GoRoute(
            path: '/showrooms',
            builder: (context, state) => const ShowroomsScreen(),
          ),
          GoRoute(
            path: '/vehicles',
            builder: (context, state) => const VehiclesScreen(),
          ),
          GoRoute(
            path: '/drivers',
            builder: (context, state) => const DriversScreen(),
          ),
          GoRoute(
            path: '/suppliers',
            builder: (context, state) => const SuppliersScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersScreen(),
          ),
          GoRoute(
            path: '/employees',
            builder: (context, state) => const EmployeesScreen(),
          ),

          // Modules à venir (phases 3 à 8 du plan de développement) —
          // navigables dès maintenant pour garder la structure cohérente.
          GoRoute(
            path: '/purchases',
            builder: (context, state) => const PurchasesScreen(),
          ),
          GoRoute(
            path: '/supplier-returns',
            builder: (context, state) => const SupplierReturnsScreen(),
          ),
          GoRoute(
            path: '/sales',
            builder: (context, state) => const SalesScreen(),
          ),
          GoRoute(
            path: '/delivery-notes',
            builder: (context, state) => const DeliveryNotesScreen(),
          ),
          GoRoute(
            path: '/customer-returns',
            builder: (context, state) => const CustomerReturnsScreen(),
          ),
          GoRoute(
            path: '/stock',
            builder: (context, state) => const StockScreen(),
          ),
          GoRoute(
            path: '/stock-movements',
            builder: (context, state) => const StockMovementsScreen(),
          ),
          GoRoute(
            path: '/transfers',
            builder: (context, state) => const TransfersScreen(),
          ),
          GoRoute(
            path: '/inventories',
            builder: (context, state) => const InventoriesScreen(),
          ),
          GoRoute(
            path: '/adjustments',
            builder: (context, state) => const AdjustmentsScreen(),
          ),
          GoRoute(path: '/pos', builder: (context, state) => const PosScreen()),
          GoRoute(
            path: '/pos/new-sale',
            builder: (context, state) => const PosSaleScreen(),
          ),
          GoRoute(
            path: '/pos/sessions',
            builder: (context, state) => const PosSessionsScreen(),
          ),
          GoRoute(
            path: '/pos/closings',
            builder: (context, state) => const PosSessionsScreen(closedOnly: true),
          ),
          GoRoute(
            path: '/payments',
            builder: (context, state) => const PaymentsScreen(),
          ),
          GoRoute(
            path: '/receivables',
            builder: (context, state) => const ReceivablesScreen(),
          ),
          GoRoute(
            path: '/payables',
            builder: (context, state) => const PayablesScreen(),
          ),
          GoRoute(
            path: '/bills-of-exchange',
            builder: (context, state) => const BillsOfExchangeScreen(),
          ),
          GoRoute(
            path: '/expenses',
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(path: '/tva', builder: (context, state) => const TvaScreen()),
          GoRoute(
            path: '/reports/sales',
            builder: (context, state) => const SalesReportScreen(),
          ),
          GoRoute(
            path: '/reports/purchases',
            builder: (context, state) => const PurchasesReportScreen(),
          ),
          GoRoute(
            path: '/reports/stock',
            builder: (context, state) => const StockReportScreen(),
          ),
          GoRoute(
            path: '/reports/margins',
            builder: (context, state) => const MarginsReportScreen(),
          ),
          GoRoute(
            path: '/reports/tva',
            builder: (context, state) => const TvaReportScreen(),
          ),
          GoRoute(
            path: '/reports/suppliers',
            builder: (context, state) => const SupplierStatementScreen(),
          ),
          GoRoute(
            path: '/reports/customers',
            builder: (context, state) => const CustomerStatementScreen(),
          ),
          GoRoute(
            path: '/permissions',
            builder: (context, state) => permissionsScreen(
              '/permissions',
              'Utilisez la liste des employés pour gérer les droits individuels.',
            ),
          ),
          GoRoute(
            path: '/sav',
            builder: (context, state) => const SavScreen(),
          ),
          GoRoute(
            path: '/audit-log',
            builder: (context, state) => const AuditLogScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
