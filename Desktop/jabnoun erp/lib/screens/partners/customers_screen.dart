import 'package:flutter/material.dart';
import '../../providers/partner_provider.dart';
import 'partners_list_screen.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PartnersListScreen(
      title: 'Clients',
      subtitle: 'Gestion des clients et de leurs informations',
      newButtonLabel: 'Nouveau client',
      repositoryProvider: customerRepositoryProvider,
      listProvider: customerListProvider,
      searchProvider: customerSearchProvider,
    );
  }
}
