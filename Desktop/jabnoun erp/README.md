# Jabnoun ERP

ERP de gestion de stock, achats, ventes, paiements et caisse.

## Stack

Flutter, Supabase/PostgreSQL, Riverpod et GoRouter.

## Configuration

Installez Flutter, puis exécutez `flutter pub get`. Créez un fichier `.env` :

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_publishable_anon_key
```

Lancez l’application avec `flutter run`.

## Supabase

Appliquez les migrations dans l’ordre. Les migrations importantes sont :

- `0010_document_immutability_rls.sql` — brouillons modifiables uniquement et RLS.
- `0011_fix_report_summary_ambiguity.sql` — correction des rapports.
- `0012_historical_sales_costing.sql` — CMUP par emplacement et coût historique des ventes.

Chaque utilisateur Auth doit avoir une ligne `employees` active et les permissions minimales dans `employee_permissions`. Ne placez jamais une clé `service_role` dans Flutter.
