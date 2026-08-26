# Configuration Supabase — Jabnoun ERP

## 1. Créer le projet
1. Créez un projet sur [supabase.com](https://supabase.com).
2. Récupérez `Project URL` et `anon public key` (Project Settings > API).
3. Renseignez-les dans le fichier `.env` à la racine du projet Flutter :
   ```
   SUPABASE_URL=https://xxxxx.supabase.co
   SUPABASE_ANON_KEY=xxxxx
   ```

## 2. Appliquer le schéma SQL
Dans l'éditeur SQL Supabase (SQL Editor), exécutez **dans l'ordre** :
1. `migrations/0001_schema.sql` — tables (employés, dépôts, showrooms, articles, partenaires, véhicules, stock).
2. `migrations/0002_rls.sql` — activation de la Row Level Security et des politiques.
3. `migrations/0003_functions.sql` — fonctions RPC (`dashboard_summary`, `partner_statement`).
4. `migrations/0004_phase3_schema.sql` — tables (paramètres entreprise, méthodes paiement, séquences documents, audit, achats, transferts, inventaires).
5. `migrations/0005_phase3_rls.sql` — RLS pour les tables Phase 3.
6. `migrations/0006_phase3_functions.sql` — RPC (validate/cancel purchase, transfer, inventory, document numbering, audit log, stock upsert).
7. `migrations/0007_phase4_8_schema.sql` — tables (ventes, bons de livraison, retours fournisseurs/clients, sessions POS, paiements, charges, ajustements).
8. `migrations/0008_phase4_8_rls.sql` — RLS pour les tables Phases 4-8.
9. `migrations/0009_phase4_8_functions.sql` — RPC (validate/cancel sale, delivery, returns, POS open/close, record_payment, validate/cancel adjustment, reports).

Ou via la CLI Supabase (si le projet est lié) :
```bash
supabase db push
```

## 3. Déployer les Edge Functions
Les fonctions `create-employee` et `reset-employee-password` nécessitent la
clé `service_role` côté serveur (jamais côté client) pour gérer les comptes
Auth des employés.

```bash
supabase functions deploy create-employee
supabase functions deploy reset-employee-password
```

Ces fonctions lisent automatiquement `SUPABASE_URL` et
`SUPABASE_SERVICE_ROLE_KEY` depuis les secrets du projet (déjà disponibles
par défaut dans l'environnement d'exécution des Edge Functions).

## 4. Créer le premier compte administrateur
Aucune interface ne permet de créer le tout premier admin (œuf et poule).
Procédez manuellement une seule fois :
1. Dans Supabase Auth, créez un utilisateur (email + mot de passe).
2. Dans la table `employees`, insérez une ligne avec le même `id`, `role = 'admin'`, `active = true`.

```sql
insert into public.employees (id, full_name, email, role, active)
values ('<uuid-de-l-utilisateur-auth>', 'Administrateur', 'admin@exemple.com', 'admin', true);
```

Vous pourrez ensuite créer tous les autres employés depuis l'application
(écran Employés), qui appelle automatiquement `create-employee`.

## 5. Notes sur les fonctions RPC
- `dashboard_summary` calcule les indicateurs de stock (valeur du stock,
  alertes de rupture/stock faible).
- `partner_statement` (Phase 1) est remplacée par `report_partner_statement`
  qui génère un relevé détaillé par fournisseur ou client.
- Les fonctions `report_sales_summary`, `report_purchases_summary`,
  `report_stock_valuation`, `report_tva_summary` alimentent les écrans de
  rapports (Phase 7).
- Toutes les opérations de stock (ventes, retours, livraisons, ajustements)
  utilisent des transactions côté serveur via `upsert_stock_level` pour
  garantir la cohérence et empêcher le stock négatif (sauf si autorisé dans
  les paramètres entreprise).
