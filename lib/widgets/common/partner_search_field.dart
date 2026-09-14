import 'package:flutter/material.dart';
import '../../models/partner.dart';

/// Champ de recherche/sélection d'un client ou fournisseur par saisie de
/// texte (nom, code, société, téléphone), au lieu d'un menu déroulant à
/// faire défiler. La liste des partenaires est déjà chargée en mémoire
/// (via customerListProvider / supplierListProvider), donc le filtrage se
/// fait localement sans appel réseau supplémentaire.
class PartnerSearchField extends StatelessWidget {
  final List<Partner> partners;
  final String? selectedId;
  final String label;
  final bool required;
  final ValueChanged<String?> onChanged;

  const PartnerSearchField({
    super.key,
    required this.partners,
    required this.selectedId,
    required this.label,
    required this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final selected = partners.where((p) => p.id == selectedId);
    final selectedName = selected.isNotEmpty ? selected.first.name : '';

    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<Partner>(
          key: ValueKey('$selectedId-${partners.length}'),
          initialValue: TextEditingValue(text: selectedName),
          displayStringForOption: (p) => p.name,
          optionsBuilder: (textEditingValue) {
            final q = textEditingValue.text.trim().toLowerCase();
            if (q.isEmpty) return partners;
            return partners.where((p) {
              return p.name.toLowerCase().contains(q) ||
                  p.code.toLowerCase().contains(q) ||
                  (p.companyName?.toLowerCase().contains(q) ?? false) ||
                  (p.phone?.toLowerCase().contains(q) ?? false);
            });
          },
          onSelected: (p) => onChanged(p.id),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: required ? '$label *' : label,
                suffixIcon: const Icon(Icons.search, size: 18),
              ),
              validator: required
                  ? (_) => selectedId == null ? 'Champ requis' : null
                  : null,
              onChanged: (v) {
                // Si l'utilisateur efface le champ, on désélectionne.
                if (v.isEmpty && selectedId != null) onChanged(null);
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final list = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(6),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth,
                    maxHeight: 220,
                  ),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: list.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Aucun résultat.'),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              final p = list[i];
                              return ListTile(
                                dense: true,
                                title: Text(p.name),
                                subtitle: Text(
                                  [
                                    p.code,
                                    if (p.companyName?.isNotEmpty == true) p.companyName,
                                    if (p.phone?.isNotEmpty == true) p.phone,
                                  ].join('  •  '),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onTap: () => onSelected(p),
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
