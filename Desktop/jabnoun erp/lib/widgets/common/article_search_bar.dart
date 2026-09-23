import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/article.dart';
import '../../repositories/article_repository.dart';

/// Server-backed selector for transaction lines. It deliberately does not use
/// the catalogue list provider, so opening a document never loads all articles.
class ArticleSearchBar extends StatefulWidget {
  final ValueChanged<Article> onSelected;
  const ArticleSearchBar({super.key, required this.onSelected});

  @override
  State<ArticleSearchBar> createState() => _ArticleSearchBarState();
}

class _ArticleSearchBarState extends State<ArticleSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _requestVersion = 0;
  List<Article> _results = const [];
  bool _loading = false;

  @override
  void dispose() { _debounce?.cancel(); _controller.dispose(); super.dispose(); }

  void _search(String value) {
    _debounce?.cancel();
    final requestVersion = ++_requestVersion;
    if (value.trim().isEmpty) { setState(() { _results = const []; _loading = false; }); return; }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final found = await ArticleRepository().fetchAll(search: value.trim(), activeOnly: true, limit: 12);
        if (mounted && requestVersion == _requestVersion) setState(() { _results = found; _loading = false; });
      } catch (_) { if (mounted && requestVersion == _requestVersion) setState(() => _loading = false); }
    });
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    TextField(controller: _controller, onChanged: _search, decoration: InputDecoration(
      hintText: 'Rechercher un article…', prefixIcon: const Icon(Icons.search),
      suffixIcon: _loading ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
    )),
    if (_results.isNotEmpty) Container(
      constraints: const BoxConstraints(maxHeight: 190), margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(4)),
      child: ListView.builder(shrinkWrap: true, itemCount: _results.length, itemBuilder: (_, i) {
        final a = _results[i];
        return Material(
          color: Colors.transparent,
          child: ListTile(
            dense: true,
            title: Text('${a.reference} — ${a.designation}'),
            subtitle: Text('Achat HT ${a.purchasePriceHt.toStringAsFixed(3)}  •  Vente HT ${a.sellingPriceHt.toStringAsFixed(3)}${a.barcode?.isNotEmpty == true ? '  •  ${a.barcode}' : ''}'),
            onTap: () { widget.onSelected(a); _controller.clear(); setState(() => _results = const []); },
          ),
        );
      }),
    ),
  ]);
}
