import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/page_scaffold.dart';

/// Tableau de bord principal. Toutes les valeurs proviennent de la fonction
/// RPC `dashboard_summary` côté Supabase (aucune donnée fictive).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final filters = ref.watch(dashboardFiltersProvider);

    return PageScaffold(
      title: 'Tableau de bord',
      subtitle: 'Vue d\'ensemble de l\'activité de l\'entreprise',
      actions: [
        _PeriodSelector(filters: filters, ref: ref),
      ],
      child: summaryAsync.when(
        data: (summary) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _KpiGrid(summary: summary),
              const SizedBox(height: 20),
              _AlertsSection(summary: summary),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Impossible de charger le tableau de bord.\n${e.toString()}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final DashboardFilters filters;
  final WidgetRef ref;
  const _PeriodSelector({required this.filters, required this.ref});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<DashboardPeriod>(
      value: filters.period,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: DashboardPeriod.today, child: Text("Aujourd'hui")),
        DropdownMenuItem(value: DashboardPeriod.week, child: Text('Cette semaine')),
        DropdownMenuItem(value: DashboardPeriod.month, child: Text('Ce mois')),
        DropdownMenuItem(value: DashboardPeriod.year, child: Text('Cette année')),
      ],
      onChanged: (period) {
        if (period == null) return;
        final now = DateTime.now();
        DateTime from;
        switch (period) {
          case DashboardPeriod.week:
            from = now.subtract(Duration(days: now.weekday - 1));
            break;
          case DashboardPeriod.month:
            from = DateTime(now.year, now.month, 1);
            break;
          case DashboardPeriod.year:
            from = DateTime(now.year, 1, 1);
            break;
          default:
            from = DateTime(now.year, now.month, now.day);
        }
        ref.read(dashboardFiltersProvider.notifier).state =
            DashboardFilters(period: period, from: from, to: now);
      },
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _KpiGrid({required this.summary});

  double _val(String key) => (summary[key] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final items = <(String, double)>[
      ('CA HT', _val('ca_ht')),
      ('CA TTC', _val('ca_ttc')),
      ('TVA collectée', _val('tva_collectee')),
      ('TVA déductible', _val('tva_deductible')),
      ('TVA à payer', _val('tva_a_payer')),
      ('Marge brute', _val('marge_brute')),
      ('Créances clients', _val('creances_clients')),
      ('Dettes fournisseurs', _val('dettes_fournisseurs')),
      ('Valeur du stock', _val('valeur_stock')),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1100 ? 4 : (constraints.maxWidth > 700 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.6,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final (label, value) = items[index];
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text('${value.toStringAsFixed(2)} ${AppConstants.defaultCurrency}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navy)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AlertsSection extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _AlertsSection({required this.summary});

  int _count(String key) => (summary[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final alerts = <(String, int)>[
      ('Articles en stock faible', _count('low_stock_count')),
      ('Articles en rupture', _count('out_of_stock_count')),
      ('Factures impayées', _count('unpaid_invoices_count')),
      ('Caisses non fermées', _count('open_pos_sessions_count')),
      ('Documents en brouillon', _count('draft_documents_count')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Alertes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final (label, count) in alerts)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: count > 0 ? AppColors.warningBg : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$label : $count',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: count > 0 ? AppColors.warning : AppColors.textSecondary)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
