-- Corrections issues d'une revue de conformité globale de l'application :
-- des tables financières/critiques exposaient des politiques RLS "for all"
-- permettant à un client (ex: appel REST direct, hors UI Flutter) de
-- modifier des lignes déjà écrites par une fonction SECURITY DEFINER,
-- contournant ainsi toute la logique métier (calcul de caisse, synchronisation
-- des soldes, permissions dédiées). Aucune partie de l'application n'utilise
-- ces écritures directes ; elles ne servaient à rien de légitime.

-- ---------------------------------------------------------------------
-- 1) POS SESSIONS : l'ouverture/fermeture doit rester exclusivement gérée
--    par open_pos_session()/close_pos_session() (calcul de l'écart de caisse,
--    horodatage, cohérence). Un accès direct permettrait de falsifier le
--    montant de clôture ou l'écart de caisse sans jamais appeler ces RPC.
-- ---------------------------------------------------------------------

drop policy if exists pos_sessions_write on public.pos_sessions;
-- pos_sessions_read (select) est conservée telle quelle.

-- ---------------------------------------------------------------------
-- 2) PAIEMENTS : doivent rester immuables une fois enregistrés (comme tous
--    les autres documents de l'application, cf. 0010_document_immutability_rls.sql).
--    Seul record_payment() peut créer un paiement (et synchronise en même
--    temps le solde de la vente/facture liée) ; aucune modification/suppression
--    directe n'est légitime.
-- ---------------------------------------------------------------------

drop policy if exists payments_write on public.payments;
-- payments_read (select) est conservée telle quelle.

-- ---------------------------------------------------------------------
-- 3) SAV : la policy générique "edit" permettait de faire passer un ticket
--    à 'resolu'/'termine' par une simple mise à jour, en contournant
--    resolve_sav_ticket()/close_sav_ticket() (permission 'resolve' dédiée,
--    type de résolution obligatoire, journalisation). Aligné sur l'intention
--    déjà documentée dans 0017_sav.sql.
-- ---------------------------------------------------------------------

drop policy if exists sav_tickets_update on public.sav_tickets;
create policy sav_tickets_update on public.sav_tickets
  for update using (public.is_admin() or public.has_permission('sav', 'edit'))
  with check (
    public.is_admin() or (
      public.has_permission('sav', 'edit') and status not in ('resolu', 'termine')
    )
  );
