import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sav_ticket.dart';
import '../../providers/sav_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/status_badge.dart';

void showSavTicketDetailDialog(BuildContext context, WidgetRef ref, SavTicket ticket) {
  showDialog(
    context: context,
    builder: (_) => _SavTicketDetailDialog(ticket: ticket),
  );
}

class _SavTicketDetailDialog extends ConsumerStatefulWidget {
  final SavTicket ticket;
  const _SavTicketDetailDialog({required this.ticket});

  @override
  ConsumerState<_SavTicketDetailDialog> createState() => _SavTicketDetailDialogState();
}

class _SavTicketDetailDialogState extends ConsumerState<_SavTicketDetailDialog> {
  final _noteCtrl = TextEditingController();
  late SavTicket _ticket;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeStatus(String status) async {
    setState(() => _busy = true);
    try {
      final updated = await ref.read(savRepositoryProvider).updateStatus(_ticket.id, status);
      setState(() => _ticket = updated);
      ref.invalidate(savTicketListProvider);
      if (mounted) showAppSnackBar(context, 'Statut mis à jour : ${savStatusLabel(status)}.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addNote() async {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(savRepositoryProvider).addNote(_ticket.id, note);
      ref.invalidate(savTicketNotesProvider(_ticket.id));
      _noteCtrl.clear();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve() async {
    String resolutionType = savResolutionTypes.first;
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setS) => AlertDialog(
          title: const Text('Résoudre le ticket'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: resolutionType,
                  decoration: const InputDecoration(labelText: 'Type de résolution *'),
                  items: [for (final t in savResolutionTypes) DropdownMenuItem(value: t, child: Text(savResolutionLabel(t)))],
                  onChanged: (v) => setS(() => resolutionType = v ?? resolutionType),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes de résolution (optionnel)'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Confirmer')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final updated = await ref.read(savRepositoryProvider).resolve(
            _ticket.id,
            resolutionType: resolutionType,
            resolutionNotes: notesCtrl.text.trim(),
          );
      setState(() => _ticket = updated);
      ref.invalidate(savTicketListProvider);
      if (mounted) showAppSnackBar(context, 'Ticket marqué comme résolu.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Clôturer le ticket',
      message: 'Confirmer la clôture définitive du ticket ${_ticket.ticketNumber} ?',
      confirmLabel: 'Clôturer',
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      final updated = await ref.read(savRepositoryProvider).close(_ticket.id);
      setState(() => _ticket = updated);
      ref.invalidate(savTicketListProvider);
      if (mounted) showAppSnackBar(context, 'Ticket clôturé.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(savTicketNotesProvider(_ticket.id));

    return AlertDialog(
      title: Row(
        children: [
          Text(_ticket.ticketNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(width: 12),
          StatusBadge.sav(_ticket.status),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Client : ${_ticket.customerName}'),
            Text('Article : ${_ticket.articleReference} — ${_ticket.articleDesignation}'),
            if (_ticket.supplierName != null) Text('Fournisseur ciblé : ${_ticket.supplierName}'),
            Text('Date de réclamation : ${_ticket.reclamationDate.day}/${_ticket.reclamationDate.month}/${_ticket.reclamationDate.year}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
              child: Text(_ticket.issueDescription),
            ),
            if (_ticket.resolutionType != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(6)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Résolution : ${savResolutionLabel(_ticket.resolutionType!)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (_ticket.resolutionNotes != null && _ticket.resolutionNotes!.isNotEmpty) Text(_ticket.resolutionNotes!),
                    if (_ticket.resolutionDate != null)
                      Text('Le ${_ticket.resolutionDate!.day}/${_ticket.resolutionDate!.month}/${_ticket.resolutionDate!.year}'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_ticket.status != 'resolu' && _ticket.status != 'termine')
              Wrap(
                spacing: 8,
                children: [
                  for (final s in ['ouvert', 'en_cours', 'en_attente_fournisseur'])
                    if (s != _ticket.status)
                      OutlinedButton(
                        onPressed: _busy ? null : () => _changeStatus(s),
                        child: Text(savStatusLabel(s)),
                      ),
                  ElevatedButton(
                    onPressed: _busy ? null : _resolve,
                    child: const Text('Marquer résolu'),
                  ),
                ],
              )
            else if (_ticket.status == 'resolu')
              ElevatedButton(onPressed: _busy ? null : _close, child: const Text('Clôturer le ticket')),
            const SizedBox(height: 16),
            const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: notesAsync.when(
                data: (notes) => notes.isEmpty
                    ? const Center(child: Text('Aucune note.', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: notes.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final n = notes[i];
                          return ListTile(
                            dense: true,
                            title: Text(n.note),
                            subtitle: Text('${n.authorName ?? ''} — ${n.createdAt.day}/${n.createdAt.month}/${n.createdAt.year}'),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(e.toString(), style: const TextStyle(color: AppColors.danger)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(labelText: 'Ajouter une note'),
                    onSubmitted: (_) => _addNote(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _busy ? null : _addNote),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
      ],
    );
  }
}
