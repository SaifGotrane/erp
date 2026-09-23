import 'package:flutter/material.dart';
import '../../models/depot.dart';
import '../../models/showroom.dart';

/// Représente un emplacement sélectionnable (dépôt ou showroom).
class LocationOption {
  final String id;
  final String name;
  final bool isDepot;

  const LocationOption({required this.id, required this.name, required this.isDepot});

  String get typeLabel => isDepot ? 'Dépôt' : 'Showroom';
}

/// Champ unique de recherche/sélection d'un emplacement (dépôt OU showroom),
/// remplaçant le double sélecteur "Type emplacement" + "Dépôt/Showroom".
/// Recherche par saisie de texte au lieu de défilement.
class LocationSearchField extends StatelessWidget {
  final List<Depot> depots;
  final List<Showroom> showrooms;
  final String? selectedDepotId;
  final String? selectedShowroomId;
  final String label;
  final bool required;
  final void Function(String? depotId, String? showroomId) onChanged;

  const LocationSearchField({
    super.key,
    required this.depots,
    required this.showrooms,
    required this.selectedDepotId,
    required this.selectedShowroomId,
    required this.label,
    required this.onChanged,
    this.required = false,
  });

  List<LocationOption> get _options => [
        for (final d in depots) LocationOption(id: d.id, name: d.name, isDepot: true),
        for (final s in showrooms) LocationOption(id: s.id, name: s.name, isDepot: false),
      ];

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final selected = options.where(
      (o) => (o.isDepot && o.id == selectedDepotId) || (!o.isDepot && o.id == selectedShowroomId),
    );
    final selectedName = selected.isNotEmpty
        ? '${selected.first.typeLabel}: ${selected.first.name}'
        : '';

    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<LocationOption>(
          key: ValueKey('$selectedDepotId-$selectedShowroomId-${options.length}'),
          initialValue: TextEditingValue(text: selectedName),
          displayStringForOption: (o) => '${o.typeLabel}: ${o.name}',
          optionsBuilder: (textEditingValue) {
            final q = textEditingValue.text.trim().toLowerCase();
            if (q.isEmpty) return options;
            return options.where((o) => o.name.toLowerCase().contains(q) || o.typeLabel.toLowerCase().contains(q));
          },
          onSelected: (o) => o.isDepot ? onChanged(o.id, null) : onChanged(null, o.id),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: required ? '$label *' : label,
                suffixIcon: const Icon(Icons.search, size: 18),
              ),
              validator: required
                  ? (_) => (selectedDepotId == null && selectedShowroomId == null) ? 'Champ requis' : null
                  : null,
              onChanged: (v) {
                if (v.isEmpty && (selectedDepotId != null || selectedShowroomId != null)) {
                  onChanged(null, null);
                }
              },
            );
          },
          optionsViewBuilder: (context, onSelected, opts) {
            final list = opts.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(6),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth, maxHeight: 220),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: list.isEmpty
                        ? const Padding(padding: EdgeInsets.all(12), child: Text('Aucun résultat.'))
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              final o = list[i];
                              return ListTile(
                                dense: true,
                                leading: Icon(o.isDepot ? Icons.warehouse_outlined : Icons.storefront_outlined, size: 18),
                                title: Text(o.name),
                                subtitle: Text(o.typeLabel, style: const TextStyle(fontSize: 11)),
                                onTap: () => onSelected(o),
                              );
                            },
                          ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
