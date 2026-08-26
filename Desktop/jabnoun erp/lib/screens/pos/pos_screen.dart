import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/pos_finance.dart';
import '../../providers/phase4_8_providers.dart';
import '../../providers/showroom_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/status_badge.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(currentOpenSessionProvider);

    return PageScaffold(
      title: 'Caisse',
      subtitle: 'Point de vente et gestion de caisse',
      actions: [
        sessionAsync.when(
          data: (session) => session == null
              ? ElevatedButton.icon(
                  onPressed: () => _showOpenDialog(context, ref),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Ouvrir la caisse'),
                )
              : Row(children: [
                  ElevatedButton.icon(
                    onPressed: () => _showCloseDialog(context, ref, session),
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Clôturer'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                  ),
                ]),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
      child: ContentCard(
        child: sessionAsync.when(
          data: (session) {
            if (session == null) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.point_of_sale, size: 64, color: AppColors.textMuted),
                    SizedBox(height: 16),
                    Text('Aucune session de caisse ouverte.', style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
                    SizedBox(height: 8),
                    Text('Cliquez sur « Ouvrir la caisse » pour démarrer.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ],
                ),
              );
            }
            return _SessionDetail(session: session);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.danger))),
        ),
      ),
    );
  }

  void _showOpenDialog(BuildContext context, WidgetRef ref) {
    final cashController = TextEditingController(text: '0');
    String? showroomId;
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final showroomsAsync = ref.watch(activeShowroomsProvider);
          return AlertDialog(
            title: const Text('Ouvrir la caisse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              showroomsAsync.when(
                data: (showrooms) => DropdownButtonFormField<String?>(
                  initialValue: showroomId,
                  decoration: const InputDecoration(labelText: 'Showroom (optionnel)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    for (final s in showrooms) DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => showroomId = v,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Fond de caisse initial (TND)'),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final cash = double.tryParse(cashController.text.trim().replaceAll(',', '.')) ?? 0;
                    await ref.read(posRepositoryProvider).openSession(showroomId: showroomId, openingCash: cash);
                    ref.invalidate(currentOpenSessionProvider);
                    ref.invalidate(posSessionListProvider);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (ctx.mounted) showAppSnackBar(ctx, 'Caisse ouverte.');
                  } catch (e) {
                    if (ctx.mounted) showAppSnackBar(ctx, e.toString(), isError: true);
                  }
                },
                child: const Text('Ouvrir'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCloseDialog(BuildContext context, WidgetRef ref, PosSession session) {
    final cashController = TextEditingController(text: session.openingCash.toString());
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clôturer la caisse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Session: ${session.sessionNumber}'),
          const SizedBox(height: 12),
          TextField(
            controller: cashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Caisse de clôture (TND)'),
          ),
          const SizedBox(height: 12),
          TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Notes (optionnel)'), maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              try {
                final cash = double.tryParse(cashController.text.trim().replaceAll(',', '.')) ?? 0;
                await ref.read(posRepositoryProvider).closeSession(session.id, cash, notes: notesController.text.trim());
                ref.invalidate(currentOpenSessionProvider);
                ref.invalidate(posSessionListProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (ctx.mounted) showAppSnackBar(ctx, 'Caisse clôturée.');
              } catch (e) {
                if (ctx.mounted) showAppSnackBar(ctx, e.toString(), isError: true);
              }
            },
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
  }
}

class _SessionDetail extends StatelessWidget {
  final PosSession session;
  const _SessionDetail({required this.session});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          _infoCard('Session', session.sessionNumber),
          _infoCard('Ouverte le', '${session.openingDate.day}/${session.openingDate.month}/${session.openingDate.year} ${session.openingDate.hour}:${session.openingDate.minute.toString().padLeft(2, '0')}'),
          _infoCard('Fond de caisse', '${session.openingCash.toStringAsFixed(3)} TND'),
          _infoCard('Statut', session.status == 'ouverte' ? 'Ouverte' : session.status),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _infoCard('Total ventes', '${session.totalSales.toStringAsFixed(3)} TND'),
          _infoCard('Ventes espèces', '${session.totalCashSales.toStringAsFixed(3)} TND'),
          _infoCard('Ventes carte', '${session.totalCardSales.toStringAsFixed(3)} TND'),
        ]),
      ],
    );
  }

  Widget _infoCard(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy)),
        ]),
      ),
    );
  }
}

class PosSessionsScreen extends ConsumerWidget {
  const PosSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(posSessionListProvider);
    final statusFilter = ref.watch(posSessionStatusFilterProvider);

    return PageScaffold(
      title: 'Sessions de caisse',
      subtitle: 'Historique des sessions d\'ouverture et de clôture',
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 180, height: 38,
              child: DropdownButtonFormField<String?>(
                initialValue: statusFilter,
                decoration: const InputDecoration(labelText: 'Statut'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tous')),
                  DropdownMenuItem(value: 'ouverte', child: Text('Ouverte')),
                  DropdownMenuItem(value: 'cloturee', child: Text('Clôturée')),
                  DropdownMenuItem(value: 'annulee', child: Text('Annulée')),
                ],
                onChanged: (v) => ref.read(posSessionStatusFilterProvider.notifier).state = v,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: async.when(
                data: (sessions) => sessions.isEmpty
                    ? const Center(child: Text('Aucune session.', style: TextStyle(color: AppColors.textMuted)))
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('N° session')),
                            DataColumn(label: Text('Employé')),
                            DataColumn(label: Text('Showroom')),
                            DataColumn(label: Text('Ouverture')),
                            DataColumn(label: Text('Clôture')),
                            DataColumn(label: Text('Ventes')),
                            DataColumn(label: Text('Écart')),
                            DataColumn(label: Text('Statut')),
                          ],
                          rows: [
                            for (final s in sessions)
                              DataRow(cells: [
                                DataCell(Text(s.sessionNumber)),
                                DataCell(Text(s.employeeName)),
                                DataCell(Text(s.showroomName)),
                                DataCell(Text('${s.openingDate.day}/${s.openingDate.month}/${s.openingDate.year}')),
                                DataCell(s.closingDate != null ? Text('${s.closingDate!.day}/${s.closingDate!.month}/${s.closingDate!.year}') : const Text('—')),
                                DataCell(Text(s.totalSales.toStringAsFixed(3))),
                                DataCell(Text((s.cashDifference ?? 0).toStringAsFixed(3))),
                                DataCell(_statusBadge(s.status)),
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

  Widget _statusBadge(String status) {
    switch (status) {
      case 'ouverte':
        return const StatusBadge(label: 'Ouverte', color: AppColors.success, background: AppColors.successBg);
      case 'cloturee':
        return const StatusBadge(label: 'Clôturée', color: AppColors.primary, background: AppColors.primaryLight);
      default:
        return const StatusBadge(label: 'Annulée', color: AppColors.danger, background: AppColors.dangerBg);
    }
  }
}
