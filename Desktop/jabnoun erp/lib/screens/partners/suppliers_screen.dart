import 'package:flutter/material.dart';
import '../../providers/partner_provider.dart';
import 'partners_list_screen.dart';

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PartnersListScreen(
      title: 'Fournisseurs',
      subtitle: 'Gestion des fournisseurs et de leurs informations',
      newButtonLabel: 'Nouveau fournisseur',
      repositoryProvider: supplierRepositoryProvider,
      listProvider: supplierListProvider,
      searchProvider: supplierSearchProvider,
      governorateFilterProvider: supplierGovernorateFilterProvider,
    );
  }
}
