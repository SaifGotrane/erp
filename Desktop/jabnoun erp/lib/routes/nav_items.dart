import 'package:flutter/material.dart';

/// Décrit une entrée de navigation dans la barre latérale.
class NavItem {
  final String label;
  final String route;
  final IconData icon;
  final String? permissionModule;

  const NavItem({
    required this.label,
    required this.route,
    required this.icon,
    this.permissionModule,
  });
}

/// Décrit une section de la barre latérale (ex: GESTION, ACHATS...).
class NavSection {
  final String title;
  final List<NavItem> items;

  const NavSection({required this.title, required this.items});
}

const List<NavSection> appNavSections = [
  NavSection(title: '', items: [
    NavItem(label: 'Tableau de bord', route: '/dashboard', icon: Icons.dashboard_outlined),
  ]),
  NavSection(title: 'GESTION', items: [
    NavItem(label: 'Articles', route: '/articles', icon: Icons.inventory_2_outlined, permissionModule: 'articles'),
    NavItem(label: 'Catégories', route: '/categories', icon: Icons.category_outlined, permissionModule: 'categories'),
    NavItem(label: 'Dépôts', route: '/depots', icon: Icons.warehouse_outlined, permissionModule: 'depots'),
    NavItem(label: 'Showrooms', route: '/showrooms', icon: Icons.storefront_outlined, permissionModule: 'showrooms'),
    NavItem(label: 'Véhicules', route: '/vehicles', icon: Icons.local_shipping_outlined, permissionModule: 'vehicles'),
    NavItem(label: 'Chauffeurs', route: '/drivers', icon: Icons.badge_outlined, permissionModule: 'drivers'),
  ]),
  NavSection(title: 'PARTENAIRES', items: [
    NavItem(label: 'Fournisseurs', route: '/suppliers', icon: Icons.local_shipping_outlined, permissionModule: 'suppliers'),
    NavItem(label: 'Clients', route: '/customers', icon: Icons.people_outline, permissionModule: 'customers'),
  ]),
  NavSection(title: 'ACHATS', items: [
    NavItem(label: 'Achats', route: '/purchases', icon: Icons.shopping_cart_outlined, permissionModule: 'purchases'),
    NavItem(label: 'Retours fournisseurs', route: '/supplier-returns', icon: Icons.undo_outlined, permissionModule: 'supplier_returns'),
  ]),
  NavSection(title: 'VENTES', items: [
    NavItem(label: 'Ventes', route: '/sales', icon: Icons.point_of_sale_outlined, permissionModule: 'sales'),
    NavItem(label: 'Bons de livraison', route: '/delivery-notes', icon: Icons.receipt_long_outlined, permissionModule: 'delivery_notes'),
    NavItem(label: 'Retours clients', route: '/customer-returns', icon: Icons.assignment_return_outlined, permissionModule: 'customer_returns'),
  ]),
  NavSection(title: 'STOCK', items: [
    NavItem(label: 'État du stock', route: '/stock', icon: Icons.bar_chart_outlined, permissionModule: 'stock'),
    NavItem(label: 'Mouvements', route: '/stock-movements', icon: Icons.swap_vert_outlined, permissionModule: 'stock'),
    NavItem(label: 'Transferts', route: '/transfers', icon: Icons.compare_arrows_outlined, permissionModule: 'transfers'),
    NavItem(label: 'Inventaires', route: '/inventories', icon: Icons.fact_check_outlined, permissionModule: 'inventories'),
    NavItem(label: 'Ajustements', route: '/adjustments', icon: Icons.tune_outlined, permissionModule: 'adjustments'),
  ]),
  NavSection(title: 'POINT DE VENTE', items: [
    NavItem(label: 'Caisse', route: '/pos', icon: Icons.point_of_sale, permissionModule: 'pos'),
    NavItem(label: 'Nouvelle vente', route: '/pos/new-sale', icon: Icons.add_shopping_cart_outlined, permissionModule: 'pos'),
    NavItem(label: 'Sessions', route: '/pos/sessions', icon: Icons.event_note_outlined, permissionModule: 'pos'),
    NavItem(label: 'Clôtures', route: '/pos/closings', icon: Icons.lock_clock_outlined, permissionModule: 'pos'),
  ]),
  NavSection(title: 'FINANCE', items: [
    NavItem(label: 'Paiements', route: '/payments', icon: Icons.payments_outlined, permissionModule: 'payments'),
    NavItem(label: 'Créances', route: '/receivables', icon: Icons.trending_up_outlined, permissionModule: 'customers'),
    NavItem(label: 'Dettes', route: '/payables', icon: Icons.trending_down_outlined, permissionModule: 'suppliers'),
    NavItem(label: 'Charges', route: '/expenses', icon: Icons.receipt_outlined, permissionModule: 'expenses'),
    NavItem(label: 'TVA', route: '/tva', icon: Icons.percent_outlined, permissionModule: 'reports'),
  ]),
  NavSection(title: 'RAPPORTS', items: [
    NavItem(label: 'Ventes', route: '/reports/sales', icon: Icons.show_chart_outlined, permissionModule: 'reports'),
    NavItem(label: 'Achats', route: '/reports/purchases', icon: Icons.insert_chart_outlined, permissionModule: 'reports'),
    NavItem(label: 'Stock', route: '/reports/stock', icon: Icons.inventory_outlined, permissionModule: 'reports'),
    NavItem(label: 'Marges', route: '/reports/margins', icon: Icons.stacked_line_chart_outlined, permissionModule: 'reports'),
    NavItem(label: 'TVA', route: '/reports/tva', icon: Icons.request_quote_outlined, permissionModule: 'reports'),
    NavItem(label: 'Fournisseurs', route: '/reports/suppliers', icon: Icons.summarize_outlined, permissionModule: 'reports'),
    NavItem(label: 'Clients', route: '/reports/customers', icon: Icons.summarize_outlined, permissionModule: 'reports'),
  ]),
  NavSection(title: 'ADMINISTRATION', items: [
    NavItem(label: 'Employés', route: '/employees', icon: Icons.groups_outlined, permissionModule: 'employees'),
    NavItem(label: "Droits d'accès", route: '/permissions', icon: Icons.admin_panel_settings_outlined, permissionModule: 'employees'),
    NavItem(label: 'Journalisation', route: '/audit-log', icon: Icons.history_outlined, permissionModule: 'journalisation'),
    NavItem(label: 'Paramètres', route: '/settings', icon: Icons.settings_outlined, permissionModule: 'settings'),
  ]),
];
