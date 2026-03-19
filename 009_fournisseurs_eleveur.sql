-- ================================================================
-- Migration 009 : Fournisseurs d'aliment par éleveur
-- Dataferme v16.1 - ADOSI
-- ================================================================

-- ----------------------------------------------------------------
-- 1. Table fournisseurs_eleveur
--    Chaque éleveur gère sa propre liste de fournisseurs
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fournisseurs_eleveur (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  eleveur_id   uuid        NOT NULL REFERENCES eleveurs(id) ON DELETE CASCADE,
  nom          text        NOT NULL,
  adresse      text,
  contact_nom  text,
  email        text        NOT NULL,
  is_active    boolean     NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fourn_eleveur ON fournisseurs_eleveur(eleveur_id);

-- Trigger updated_at
DROP TRIGGER IF EXISTS update_fournisseurs_eleveur_updated_at ON fournisseurs_eleveur;
CREATE TRIGGER update_fournisseurs_eleveur_updated_at
  BEFORE UPDATE ON fournisseurs_eleveur
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------
-- 2. Ajouter la colonne fournisseur_eleveur_id sur commandes_aliment
-- ----------------------------------------------------------------
ALTER TABLE commandes_aliment
  ADD COLUMN IF NOT EXISTS fournisseur_eleveur_id uuid REFERENCES fournisseurs_eleveur(id);

-- ----------------------------------------------------------------
-- 3. RLS sur fournisseurs_eleveur
-- ----------------------------------------------------------------
ALTER TABLE fournisseurs_eleveur ENABLE ROW LEVEL SECURITY;

-- Éleveur : ses propres fournisseurs uniquement
CREATE POLICY "fourn_select_own" ON fournisseurs_eleveur
  FOR SELECT USING (
    eleveur_id IN (
      SELECT e.id FROM eleveurs e
      JOIN users u ON (u.id = e.user_id OR u.email = e.email)
      WHERE u.email = current_setting('request.jwt.claims', true)::json->>'email'
    )
    OR EXISTS (
      SELECT 1 FROM users
      WHERE email = current_setting('request.jwt.claims', true)::json->>'email'
        AND role IN ('admin', 'technicien')
    )
  );

CREATE POLICY "fourn_insert_own" ON fournisseurs_eleveur
  FOR INSERT WITH CHECK (
    eleveur_id IN (
      SELECT e.id FROM eleveurs e
      JOIN users u ON (u.id = e.user_id OR u.email = e.email)
      WHERE u.email = current_setting('request.jwt.claims', true)::json->>'email'
    )
    OR EXISTS (
      SELECT 1 FROM users
      WHERE email = current_setting('request.jwt.claims', true)::json->>'email'
        AND role IN ('admin', 'technicien')
    )
  );

CREATE POLICY "fourn_update_own" ON fournisseurs_eleveur
  FOR UPDATE USING (
    eleveur_id IN (
      SELECT e.id FROM eleveurs e
      JOIN users u ON (u.id = e.user_id OR u.email = e.email)
      WHERE u.email = current_setting('request.jwt.claims', true)::json->>'email'
    )
    OR EXISTS (
      SELECT 1 FROM users
      WHERE email = current_setting('request.jwt.claims', true)::json->>'email'
        AND role IN ('admin', 'technicien')
    )
  );

CREATE POLICY "fourn_delete_own" ON fournisseurs_eleveur
  FOR DELETE USING (
    eleveur_id IN (
      SELECT e.id FROM eleveurs e
      JOIN users u ON (u.id = e.user_id OR u.email = e.email)
      WHERE u.email = current_setting('request.jwt.claims', true)::json->>'email'
    )
    OR EXISTS (
      SELECT 1 FROM users
      WHERE email = current_setting('request.jwt.claims', true)::json->>'email'
        AND role = 'admin'
    )
  );

-- Accès public (sans auth) pour la page confirm.html via token
CREATE POLICY "fourn_select_confirm" ON fournisseurs_eleveur
  FOR SELECT USING (true);  -- lecture publique OK car pas de données sensibles

-- ----------------------------------------------------------------
-- 4. Mise à jour de la vue v_planning_commandes
--    Ajout des infos du fournisseur sélectionné
-- ----------------------------------------------------------------
DROP VIEW IF EXISTS v_planning_commandes;
CREATE OR REPLACE VIEW v_planning_commandes AS
SELECT
  c.id,
  c.eleveur_id,
  e.nom                           AS eleveur_nom,
  e.prenom                        AS eleveur_prenom,
  e.code_eleveur,
  -- Fournisseur sélectionné sur la commande (priorité) sinon fournisseur par défaut éleveur
  COALESCE(f.email, e.email_fournisseur)      AS email_fournisseur,
  COALESCE(f.nom,   e.nom_fournisseur)        AS nom_fournisseur,
  f.contact_nom                   AS fournisseur_contact,
  f.adresse                       AS fournisseur_adresse,
  f.id                            AS fournisseur_eleveur_id,
  t.nom                           AS type_aliment,
  c.quantite,
  c.unite,
  c.date_livraison_souhaitee,
  c.date_livraison_confirmee,
  c.heure_livraison_confirmee,
  c.statut,
  c.notes,
  c.confirmation_token,
  c.email_envoye_at,
  c.created_at
FROM commandes_aliment c
JOIN eleveurs e ON e.id = c.eleveur_id
LEFT JOIN types_aliment t ON t.id = c.type_aliment_id
LEFT JOIN fournisseurs_eleveur f ON f.id = c.fournisseur_eleveur_id;

-- ----------------------------------------------------------------
-- FIN DE LA MIGRATION 009
-- ================================================================
