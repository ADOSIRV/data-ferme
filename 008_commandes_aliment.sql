-- ================================================================
-- Migration 008 : Commandes d'aliment + Planning
-- Dataferme v16.0 - ADOSI
-- ================================================================

-- ----------------------------------------------------------------
-- 1. Ajout colonnes fournisseur sur la table eleveurs
-- ----------------------------------------------------------------
ALTER TABLE eleveurs
  ADD COLUMN IF NOT EXISTS nom_fournisseur  text,
  ADD COLUMN IF NOT EXISTS email_fournisseur text;

-- ----------------------------------------------------------------
-- 2. Table types_aliment (liste configurable par l'admin)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS types_aliment (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom         text NOT NULL,
  description text,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Données initiales
INSERT INTO types_aliment (nom, description) VALUES
  ('Démarrage',  'Aliment pour poussins 0-10 jours'),
  ('Croissance', 'Aliment pour phase de croissance'),
  ('Finition',   'Aliment pour phase de finition'),
  ('Pré-ponte',  'Aliment de transition avant la ponte'),
  ('Ponte',      'Aliment pour poules en production')
ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------
-- 3. Table commandes_aliment
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS commandes_aliment (
  id                            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  eleveur_id                    uuid        NOT NULL REFERENCES eleveurs(id) ON DELETE CASCADE,
  type_aliment_id               uuid        REFERENCES types_aliment(id),
  quantite                      numeric     NOT NULL CHECK (quantite > 0),
  unite                         text        NOT NULL DEFAULT 'tonnes',
  date_livraison_souhaitee      date        NOT NULL,
  date_livraison_confirmee      date,
  heure_livraison_confirmee     text,
  statut                        text        NOT NULL DEFAULT 'en_attente'
                                            CHECK (statut IN ('en_attente','confirmee','livree','annulee')),
  notes                         text,
  confirmation_token            uuid        NOT NULL DEFAULT gen_random_uuid(),
  confirmation_token_expire_at  timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  email_envoye_at               timestamptz,
  created_at                    timestamptz NOT NULL DEFAULT now(),
  updated_at                    timestamptz NOT NULL DEFAULT now()
);

-- Index pour les requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_commandes_eleveur  ON commandes_aliment(eleveur_id);
CREATE INDEX IF NOT EXISTS idx_commandes_statut   ON commandes_aliment(statut);
CREATE INDEX IF NOT EXISTS idx_commandes_token    ON commandes_aliment(confirmation_token);
CREATE INDEX IF NOT EXISTS idx_commandes_dates    ON commandes_aliment(date_livraison_souhaitee);

-- ----------------------------------------------------------------
-- 4. RLS (Row Level Security)
-- ----------------------------------------------------------------
ALTER TABLE types_aliment     ENABLE ROW LEVEL SECURITY;
ALTER TABLE commandes_aliment ENABLE ROW LEVEL SECURITY;

-- types_aliment : lecture publique (utilisée sans auth pour confirm.html)
CREATE POLICY "types_aliment_read_all" ON types_aliment
  FOR SELECT USING (true);

-- types_aliment : écriture admin uniquement
CREATE POLICY "types_aliment_admin_write" ON types_aliment
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE email = current_setting('request.jwt.claims', true)::json->>'email'
        AND role = 'admin'
    )
  );

-- commandes_aliment : lecture/écriture publique via token (pour confirm.html)
-- Le token doit être valide et non expiré
CREATE POLICY "commandes_confirm_by_token" ON commandes_aliment
  FOR UPDATE USING (
    confirmation_token = (current_setting('request.headers', true)::json->>'x-confirm-token')::uuid
    AND confirmation_token_expire_at > now()
    AND statut = 'en_attente'
  );

-- commandes_aliment : SELECT via token (pour afficher le formulaire de confirmation)
CREATE POLICY "commandes_select_by_token" ON commandes_aliment
  FOR SELECT USING (
    confirmation_token = (current_setting('request.headers', true)::json->>'x-confirm-token')::uuid
    OR EXISTS (
      SELECT 1 FROM users u
      WHERE u.email = current_setting('request.jwt.claims', true)::json->>'email'
        AND (
          u.role IN ('admin', 'technicien')
          OR EXISTS (
            SELECT 1 FROM eleveurs e
            WHERE e.id = commandes_aliment.eleveur_id
              AND (e.user_id = u.id OR e.email = u.email)
          )
        )
    )
  );

-- commandes_aliment : INSERT pour utilisateurs connectés (éleveur pour son compte)
CREATE POLICY "commandes_insert_own" ON commandes_aliment
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u
      JOIN eleveurs e ON (e.user_id = u.id OR e.email = u.email)
      WHERE u.email = current_setting('request.jwt.claims', true)::json->>'email'
        AND e.id = commandes_aliment.eleveur_id
        AND e.is_active = true
    )
    OR EXISTS (
      SELECT 1 FROM users
      WHERE email = current_setting('request.jwt.claims', true)::json->>'email'
        AND role IN ('admin', 'technicien')
    )
  );

-- commandes_aliment : UPDATE pour admin/technicien (annulation, modification)
CREATE POLICY "commandes_update_admin" ON commandes_aliment
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE email = current_setting('request.jwt.claims', true)::json->>'email'
        AND role IN ('admin', 'technicien')
    )
  );

-- ----------------------------------------------------------------
-- 5. Fonction trigger : mise à jour automatique de updated_at
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_commandes_aliment_updated_at ON commandes_aliment;
CREATE TRIGGER update_commandes_aliment_updated_at
  BEFORE UPDATE ON commandes_aliment
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------
-- 6. Vue pour le planning (joins avec types et éleveurs)
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW v_planning_commandes AS
SELECT
  c.id,
  c.eleveur_id,
  e.nom                       AS eleveur_nom,
  e.prenom                    AS eleveur_prenom,
  e.code_eleveur,
  e.email_fournisseur,
  e.nom_fournisseur,
  t.nom                       AS type_aliment,
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
LEFT JOIN types_aliment t ON t.id = c.type_aliment_id;

-- ================================================================
-- FIN DE LA MIGRATION 008
-- ================================================================
