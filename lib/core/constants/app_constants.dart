/// Constantes générales de l'application (non liées à la persistance).
class AppConstants {
  AppConstants._();

  static const String appName = 'Jabnoun ERP';
  static const String defaultCurrency = 'TND';

  /// Clé de stockage local pour la session.
  static const String prefsLastEmail = 'last_email';
}

/// Codes des modules utilisés pour la gestion des permissions.
/// Doivent correspondre à la colonne `module` dans `employee_permissions`.
class PermissionModule {
  PermissionModule._();

  static const String articles = 'articles';
  static const String categories = 'categories';
  static const String depots = 'depots';
  static const String showrooms = 'showrooms';
  static const String vehicles = 'vehicles';
  static const String drivers = 'drivers';
  static const String suppliers = 'suppliers';
  static const String customers = 'customers';
  static const String purchases = 'purchases';
  static const String supplierReturns = 'supplier_returns';
  static const String sales = 'sales';
  static const String deliveryNotes = 'delivery_notes';
  static const String customerReturns = 'customer_returns';
  static const String stock = 'stock';
  static const String transfers = 'transfers';
  static const String inventories = 'inventories';
  static const String adjustments = 'adjustments';
  static const String pos = 'pos';
  static const String payments = 'payments';
  static const String expenses = 'expenses';
  static const String reports = 'reports';
  static const String journalisation = 'journalisation';
  static const String employees = 'employees';
  static const String settings = 'settings';
  static const String subInvoices = 'sub_invoices';
  static const String subClients = 'sub_clients';
  static const String billsOfExchange = 'bills_of_exchange';
  static const String supplierSettlements = 'supplier_settlements';
  static const String sav = 'sav';

  static const List<String> all = [
    articles,
    categories,
    depots,
    showrooms,
    vehicles,
    drivers,
    suppliers,
    customers,
    purchases,
    supplierReturns,
    sales,
    deliveryNotes,
    customerReturns,
    stock,
    transfers,
    inventories,
    adjustments,
    pos,
    payments,
    expenses,
    reports,
    journalisation,
    employees,
    settings,
    subInvoices,
    subClients,
    billsOfExchange,
    supplierSettlements,
    sav,
  ];
}

/// Actions possibles pour un module (les modules n'utilisent pas tous
/// toutes les actions - voir [PermissionModule]).
class PermissionAction {
  PermissionAction._();

  static const String view = 'view';
  static const String create = 'create';
  static const String edit = 'edit';
  static const String delete = 'delete';
  static const String validate = 'validate';
  static const String cancel = 'cancel';
  static const String adjustStock = 'adjust_stock';
  static const String transferStock = 'transfer_stock';
  static const String openPos = 'open_pos';
  static const String sellPos = 'sell_pos';
  static const String cancelSalePos = 'cancel_sale_pos';
  static const String closePos = 'close_pos';
  static const String viewRevenuePos = 'view_revenue_pos';
  static const String export = 'export';
  static const String markPaid = 'mark_paid';
  static const String print = 'print';
  static const String resolve = 'resolve';
}

/// Statuts génériques de documents (achats, ventes, transferts...).
class DocStatus {
  DocStatus._();

  static const String draft = 'brouillon';
  static const String validated = 'valide';
  static const String partiallyPaid = 'partiellement_paye';
  static const String paid = 'paye';
  static const String unpaid = 'impaye';
  static const String cancelled = 'annule';
}

/// Types de mouvements de stock.
class StockMovementType {
  StockMovementType._();

  static const String entree = 'entree';
  static const String sortie = 'sortie';
  static const String transfert = 'transfert';
  static const String vente = 'vente';
  static const String retourFournisseur = 'retour_fournisseur';
  static const String retourClient = 'retour_client';
  static const String ajustement = 'ajustement';
  static const String inventaire = 'inventaire';
}

/// Préfixes de numérotation automatique des documents.
class DocPrefix {
  DocPrefix._();

  static const String bonLivraison = 'BL';
  static const String bonSortie = 'BS';
  static const String achat = 'ACH';
  static const String vente = 'VTE';
  static const String retour = 'RET';
  static const String transfert = 'TRF';
  static const String inventaire = 'INV';
}
