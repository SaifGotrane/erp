import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pos_finance.dart';
import '../../providers/article_provider.dart';
import '../../providers/phase4_8_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/article_search_bar.dart';

void showAdjustmentLinesDialog(
  BuildContext context,
  StockAdjustment adjustment,
) {
  showDialog(
    context: context,
    builder: (_) => _AdjustmentLinesDialog(adjustment: adjustment),
  );
}

class _AdjustmentLinesDialog extends ConsumerStatefulWidget {
  final StockAdjustment adjustment;
  const _AdjustmentLinesDialog({required this.adjustment});

  @override
  ConsumerState<_AdjustmentLinesDialog> createState() =>
      _AdjustmentLinesDialogState();
}

class _AdjustmentLinesDialogState
    extends ConsumerState<_AdjustmentLinesDialog> {
  final List<_Line> _lines = [];
  bool _saving = false;
  bool _initialised = false;

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(adjustmentRepositoryProvider)
          .replaceLines(
            widget.adjustment.id,
            _lines
                .map(
                  (line) => StockAdjustmentLine(
                    id: '',
                    adjustmentId: widget.adjustment.id,
                    articleId: line.articleId,
                    currentQuantity: line.currentQuantity,
                    newQuantity: line.newQuantity,
                    delta: line.newQuantity - line.currentQuantity,
                  ),
                )
                .toList(),
          );
      ref.invalidate(adjustmentListProvider);
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        showAppSnackBar(context, 'Lignes de l\'ajustement enregistrées.');
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialised) {
      _initialised = true;
      for (final existing in widget.adjustment.lines) {
        _lines.add(
          _Line(
            existing.articleId,
            '${existing.articleReference} — ${existing.articleDesignation}',
            currentQuantity: existing.currentQuantity,
            newQuantity: existing.newQuantity,
          ),
        );
      }
    }
    return AlertDialog(
      title: Text(
        'Lignes — ${widget.adjustment.documentNumber}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
      content: SizedBox(
        width: 700,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ArticleSearchBar(
              onSelected: (article) => setState(() => _lines.add(_Line(
                article.id,
                '${article.reference} — ${article.designation}',
              ))),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _lines.isEmpty
                  ? const Center(
                      child: Text(
                        'Ajoutez les articles à ajuster.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _lines.length,
                      itemBuilder: (_, index) {
                        final line = _lines[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(line.label)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: line.current,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Qté actuelle',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: line.next,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Nouvelle qté',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: AppColors.danger,
                                ),
                                onPressed: () => setState(() {
                                  line.dispose();
                                  _lines.removeAt(index);
                                }),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Enregistrer les lignes'),
        ),
      ],
    );
  }
}

class _Line {
  final String articleId;
  final String label;
  final TextEditingController current;
  final TextEditingController next;
  _Line(
    this.articleId,
    this.label, {
    double currentQuantity = 0,
    double newQuantity = 0,
  }) : current = TextEditingController(text: currentQuantity.toString()),
       next = TextEditingController(text: newQuantity.toString());
  double get currentQuantity =>
      double.tryParse(current.text.replaceAll(',', '.')) ?? 0;
  double get newQuantity =>
      double.tryParse(next.text.replaceAll(',', '.')) ?? 0;
  void dispose() {
    current.dispose();
    next.dispose();
  }
}
