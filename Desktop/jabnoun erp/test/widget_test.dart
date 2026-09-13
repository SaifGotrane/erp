// Tests de base de l'application Jabnoun ERP.
//
// Remarque : les tests d'intégration nécessitant Supabase (connexion,
// chargement de données) doivent être ajoutés séparément avec des mocks,
// car ce test smoke ne configure pas de session Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:jabnoun_erp/theme/app_theme.dart';

void main() {
  test('Le thème applicatif se construit sans erreur', () {
    final theme = AppTheme.light;
    expect(theme.useMaterial3, isTrue);
  });
}
