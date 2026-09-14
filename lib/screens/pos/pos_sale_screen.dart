import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/phase4_8_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/page_scaffold.dart';
import '../sales/sale_form_dialog.dart';

/// Point d'entrée dédié aux ventes comptoir. Une session ouverte est requise;
/// le formulaire crée, valide et encaisse la vente dans cette même session.
class PosSaleScreen extends ConsumerWidget {
  const PosSaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentOpenSessionProvider);
    return PageScaffold(
      title: 'Nouvelle vente comptoir',
      subtitle: 'Sélection rapide des articles et encaissement immédiat',
      child: ContentCard(
        child: session.when(
          data: (value) => value == null
              ? const Center(
                  child: Text(
                    'Ouvrez une session de caisse avant de créer une vente comptoir.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('Démarrer la vente comptoir'),
                    onPressed: () => showSaleFormDialog(
                      context,
                      ref,
                      isPos: true,
                      posSessionId: value.id,
                    ),
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              error.toString(),
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      ),
    );
  }
}
