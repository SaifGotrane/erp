import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository());

enum DashboardPeriod { today, week, month, year, custom }

class DashboardFilters {
  final DashboardPeriod period;
  final DateTime from;
  final DateTime to;
  final String? depotId;
  final String? showroomId;

  const DashboardFilters({
    required this.period,
    required this.from,
    required this.to,
    this.depotId,
    this.showroomId,
  });

  static DashboardFilters forToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return DashboardFilters(period: DashboardPeriod.today, from: start, to: now);
  }
}

final dashboardFiltersProvider = StateProvider<DashboardFilters>((ref) => DashboardFilters.forToday());

final dashboardSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final filters = ref.watch(dashboardFiltersProvider);
  return ref.watch(dashboardRepositoryProvider).fetchSummary(
        from: filters.from,
        to: filters.to,
        depotId: filters.depotId,
        showroomId: filters.showroomId,
      );
});
