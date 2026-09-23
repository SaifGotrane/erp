import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/purchase.dart';
import '../models/stock_transfer.dart';
import '../models/inventory.dart';
import '../models/audit_log.dart';
import '../repositories/purchase_repository.dart';
import '../repositories/transfer_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/stock_repository.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) => PurchaseRepository());
final transferRepositoryProvider = Provider<TransferRepository>((ref) => TransferRepository());
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) => InventoryRepository());
final stockRepositoryProvider = Provider<StockRepository>((ref) => StockRepository());
final auditRepositoryProvider = Provider<AuditRepository>((ref) => AuditRepository());
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

// --- Purchases: list state + provider ---

final purchaseSearchProvider = StateProvider<String>((ref) => '');
final purchaseStatusFilterProvider = StateProvider<String?>((ref) => null);

final purchaseListProvider = FutureProvider<List<Purchase>>((ref) async {
  final search = ref.watch(purchaseSearchProvider);
  final status = ref.watch(purchaseStatusFilterProvider);
  return ref.watch(purchaseRepositoryProvider).fetchAll(search: search, status: status);
});

// --- Factures achats (écran dédié, filtres indépendants de l'écran Achats) ---

const List<String> purchaseInvoiceStatuses = ['valide', 'partiellement_paye', 'paye'];

final invoicePurchasesSearchProvider = StateProvider<String>((ref) => '');
final invoicePurchasesDateFromProvider = StateProvider<DateTime?>((ref) => null);
final invoicePurchasesDateToProvider = StateProvider<DateTime?>((ref) => null);

final invoicePurchasesListProvider = FutureProvider<List<Purchase>>((ref) async {
  final search = ref.watch(invoicePurchasesSearchProvider);
  final from = ref.watch(invoicePurchasesDateFromProvider);
  final to = ref.watch(invoicePurchasesDateToProvider);
  return ref.watch(purchaseRepositoryProvider).fetchAll(
        search: search,
        statuses: purchaseInvoiceStatuses,
        from: from,
        to: to,
        limit: 200,
      );
});

// --- Transfers: list state + provider ---

final transferSearchProvider = StateProvider<String>((ref) => '');
final transferStatusFilterProvider = StateProvider<String?>((ref) => null);

final transferListProvider = FutureProvider<List<StockTransfer>>((ref) async {
  final search = ref.watch(transferSearchProvider);
  final status = ref.watch(transferStatusFilterProvider);
  return ref.watch(transferRepositoryProvider).fetchAll(search: search, status: status);
});

// --- Inventories: list state + provider ---

final inventorySearchProvider = StateProvider<String>((ref) => '');
final inventoryStatusFilterProvider = StateProvider<String?>((ref) => null);

final inventoryListProvider = FutureProvider<List<Inventory>>((ref) async {
  final search = ref.watch(inventorySearchProvider);
  final status = ref.watch(inventoryStatusFilterProvider);
  return ref.watch(inventoryRepositoryProvider).fetchAll(search: search, status: status);
});

// --- Stock levels: list state + provider ---

final stockSearchProvider = StateProvider<String>((ref) => '');
final stockDepotFilterProvider = StateProvider<String?>((ref) => null);
final stockShowroomFilterProvider = StateProvider<String?>((ref) => null);
final stockLowStockOnlyProvider = StateProvider<bool>((ref) => false);

final stockLevelsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final search = ref.watch(stockSearchProvider);
  final depotId = ref.watch(stockDepotFilterProvider);
  final showroomId = ref.watch(stockShowroomFilterProvider);
  final lowStockOnly = ref.watch(stockLowStockOnlyProvider);
  return ref.watch(stockRepositoryProvider).fetchStockLevels(
        depotId: depotId,
        showroomId: showroomId,
        search: search,
        lowStockOnly: lowStockOnly,
      );
});

// --- Stock movements: list state + provider ---

final stockMovementTypeFilterProvider = StateProvider<String?>((ref) => null);
final stockMovementDepotFilterProvider = StateProvider<String?>((ref) => null);

final stockMovementsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final movementType = ref.watch(stockMovementTypeFilterProvider);
  final depotId = ref.watch(stockMovementDepotFilterProvider);
  return ref.watch(stockRepositoryProvider).fetchMovements(
        movementType: movementType,
        depotId: depotId,
      );
});

// --- Audit logs: list state + provider ---

final auditModuleFilterProvider = StateProvider<String?>((ref) => null);

final auditLogsProvider = FutureProvider<List<AuditLog>>((ref) async {
  final module = ref.watch(auditModuleFilterProvider);
  return ref.watch(auditRepositoryProvider).fetchAll(module: module);
});

// --- Payment methods ---

final paymentMethodsProvider = FutureProvider<List<PaymentMethod>>((ref) {
  return ref.watch(settingsRepositoryProvider).fetchPaymentMethods(activeOnly: true);
});
