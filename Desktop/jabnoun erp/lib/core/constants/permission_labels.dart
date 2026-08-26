import 'app_constants.dart';

/// Libellés français pour l'affichage de la matrice de permissions
/// (voir cahier des charges §5).
class PermissionLabels {
  PermissionLabels._();

  static const Map<String, String> modules = {
    PermissionModule.articles: 'Articles',
    PermissionModule.categories: 'Catégories',
    PermissionModule.depots: 'Dépôts',
    PermissionModule.showrooms: 'Showrooms',
    PermissionModule.vehicles: 'Véhicules',
    PermissionModule.drivers: 'Chauffeurs',
    PermissionModule.suppliers: 'Fournisseurs',
    PermissionModule.customers: 'Clients',
    PermissionModule.purchases: 'Achats',
    PermissionModule.supplierReturns: 'Retours fournisseurs',
    PermissionModule.sales: 'Ventes',
    PermissionModule.deliveryNotes: 'Bons de livraison',
    PermissionModule.customerReturns: 'Retours clients',
    PermissionModule.stock: 'Stock',
    PermissionModule.transfers: 'Transferts',
    PermissionModule.inventories: 'Inventaires',
    PermissionModule.adjustments: 'Ajustements',
    PermissionModule.pos: 'Point de vente',
    PermissionModule.payments: 'Paiements',
    PermissionModule.expenses: 'Charges',
    PermissionModule.reports: 'Rapports',
    PermissionModule.journalisation: 'Journalisation',
    PermissionModule.employees: 'Employés',
    PermissionModule.settings: 'Paramètres',
  };

  static const Map<String, String> actions = {
    PermissionAction.view: 'Voir',
    PermissionAction.create: 'Ajouter',
    PermissionAction.edit: 'Modifier',
    PermissionAction.delete: 'Supprimer',
    PermissionAction.validate: 'Valider',
    PermissionAction.cancel: 'Annuler',
    PermissionAction.adjustStock: 'Ajuster',
    PermissionAction.transferStock: 'Transférer',
    PermissionAction.openPos: 'Ouvrir',
    PermissionAction.sellPos: 'Vendre',
    PermissionAction.cancelSalePos: 'Annuler vente',
    PermissionAction.closePos: 'Fermer caisse',
    PermissionAction.viewRevenuePos: 'Voir recettes',
    PermissionAction.export: 'Exporter',
  };

  static String module(String key) => modules[key] ?? key;
  static String action(String key) => actions[key] ?? key;
}
