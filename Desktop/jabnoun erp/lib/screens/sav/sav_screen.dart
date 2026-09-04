import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sav_ticket.dart';
import '../../providers/partner_provider.dart';
import '../../providers/sav_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import 'sav_ticket_detail_dialog.dart';
import 'sav_ticket_form_dialog.dart';

class SavScreen extends ConsumerWidget {
  const SavScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(savTicketListProvider);
    final search = ref.watch(savSearchProvider);
    final statusFilter = ref.watch(savStatusFilterProvider);
    final customerFilter = ref.watch(savCustomerFilterProvider);
    final customersAsync = ref.watch(customerListProvider);

    return PageScaffold(
      title: 'Service Après-Vente',
      subtitle: 'Suivi des réclamations clients et de leur résolution',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showSavTicketFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau ticket'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AppSearchField(
                  hint: 'Rechercher par n° de ticket',
                  initialValue: search,
                  onChanged: (v) => ref.read(savSearchProvider.notifier).state = v,
                ),
                SizedBox(
                  width: 200,
                  height: 38,
                  child: DropdownButtonFormField<String?>(
                    initialValue: statusFilter,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous les statuts')),
                      for (final s in savStatuses) DropdownMenuItem(value: s, child: Text(savStatusLabel(s))),
                    ],
                    onChanged: (v) => ref.read(savStatusFilterProvider.notifier).state = v,
                  ),
                ),
                SizedBox(
                  width: 220,
                  height: 38,
                  child: customersAsync.when(
                    data: (customers) => DropdownButtonFormField<String?>(
                      initialValue: customerFilter,
                      decoration: const InputDecoration(labelText: 'Client'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tous les clients')),
                        for (final c in customers) DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => ref.read(savCustomerFilterProvider.notifier).state = v,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ticketsAsync.when(
                data: (tickets) => tickets.isEmpty
                    ? const Center(child: Text('Aucun ticket SAV.', style: TextStyle(color: AppColors.textMuted)))
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('N° ticket')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Client')),
                            DataColumn(label: Text('Article')),
                            DataColumn(label: Text('Fournisseur')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final t in tickets)
                              DataRow(cells: [
                                DataCell(Text(t.ticketNumber)),
                                DataCell(Text('${t.reclamationDate.day}/${t.reclamationDate.month}/${t.reclamationDate.year}')),
                                DataCell(Text(t.customerName)),
                                DataCell(Text('${t.articleReference} — ${t.articleDesignation}')),
                                DataCell(Text(t.supplierName ?? '—')),
                                DataCell(StatusBadge.sav(t.status)),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                                    tooltip: 'Ouvrir',
                                    onPressed: () => showSavTicketDetailDialog(context, ref, t),
                                  ),
                                ),
                              ]),
                          ],
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.danger))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
