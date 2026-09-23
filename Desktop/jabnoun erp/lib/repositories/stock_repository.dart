import '../models/audit_log.dart';
import 'base_repository.dart';

class StockRepository extends BaseRepository {
  /// Fetch current stock levels with article info, optionally filtered by depot/showroom.
  Future<List<Map<String, dynamic>>> fetchStockLevels({
    String? depotId,
    String? showroomId,
    String? search,
    bool lowStockOnly = false,
    int limit = 100,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client.from('stock_levels').select(
          'quantity, article:articles(id, reference, designation, min_stock, active), depot:depots(name), showroom:showrooms(name)');
      if (depotId != null) {
        query = query.eq('depot_id', depotId);
      }
      if (showroomId != null) {
        query = query.eq('showroom_id', showroomId);
      }
      final data = await query.order('updated_at', ascending: false).range(offset, offset + limit - 1);
      var results = (data as List).cast<Map<String, dynamic>>();

      if (lowStockOnly) {
        results = results.where((row) {
          final article = row['article'] as Map<String, dynamic>?;
          if (article == null) return false;
          final qty = (row['quantity'] as num?)?.toDouble() ?? 0;
          final minStock = (article['min_stock'] as num?)?.toDouble() ?? 0;
          return qty <= minStock;
        }).toList();
      }

      if (search != null && search.trim().isNotEmpty) {
        final s = search.toLowerCase();
        results = results.where((row) {
          final article = row['article'] as Map<String, dynamic>?;
          if (article == null) return false;
          final ref = (article['reference'] as String?)?.toLowerCase() ?? '';
          final desig = (article['designation'] as String?)?.toLowerCase() ?? '';
          return ref.contains(s) || desig.contains(s);
        }).toList();
      }

      return results;
    });
  }

  /// Fetch stock movements history with article info.
  Future<List<Map<String, dynamic>>> fetchMovements({
    String? articleId,
    String? movementType,
    String? depotId,
    String? showroomId,
    int limit = 100,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client.from('stock_movements').select(
          '*, article:articles(reference, designation)');
      if (articleId != null) {
        query = query.eq('article_id', articleId);
      }
      if (movementType != null) {
        query = query.eq('movement_type', movementType);
      }
      if (depotId != null) {
        query = query.or('source_depot_id.eq.$depotId,destination_depot_id.eq.$depotId');
      }
      if (showroomId != null) {
        query = query.or('source_showroom_id.eq.$showroomId,destination_showroom_id.eq.$showroomId');
      }
      final data = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
      return (data as List).cast<Map<String, dynamic>>();
    });
  }
}

class AuditRepository extends BaseRepository {
  Future<List<AuditLog>> fetchAll({
    String? module,
    String? action,
    String? userId,
    int limit = 100,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client.from('audit_logs').select('*, user:employees(full_name)');
      if (module != null) {
        query = query.eq('module', module);
      }
      if (action != null) {
        query = query.eq('action', action);
      }
      if (userId != null) {
        query = query.eq('user_id', userId);
      }
      final data = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
      return (data as List).map((e) => AuditLog.fromMap(e as Map<String, dynamic>)).toList();
    });
  }
}

class SettingsRepository extends BaseRepository {
  Future<CompanySettings> fetchSettings() {
    return guard(() async {
      final data = await client.from('company_settings').select().limit(1).maybeSingle();
      if (data == null) {
        final created = await client.from('company_settings').insert({
          'company_name': 'Entreprise',
          'currency': 'TND',
          'allow_negative_stock': false,
          'cnss_employee_rate': 0.0918,
          'css_rate': 0.01,
          'professional_expenses_rate': 0.10,
          'professional_expenses_annual_cap': 2000,
          'head_of_household_annual_deduction': 300,
          'child_annual_deduction': 100,
          'max_deductible_children': 4,
          'updated_at': DateTime.now().toIso8601String(),
        }).select().single();
        return CompanySettings.fromMap(created);
      }
      return CompanySettings.fromMap(data);
    });
  }

  Future<CompanySettings> updateSettings(CompanySettings settings) {
    return guard(() async {
      final data = await client.from('company_settings').update(settings.toUpdateMap()).eq('id', settings.id).select().single();
      return CompanySettings.fromMap(data);
    });
  }

  Future<List<PaymentMethod>> fetchPaymentMethods({bool activeOnly = false}) {
    return guard(() async {
      var query = client.from('payment_methods').select();
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final data = await query.order('sort_order');
      return (data as List).map((e) => PaymentMethod.fromMap(e as Map<String, dynamic>)).toList();
    });
  }
}
