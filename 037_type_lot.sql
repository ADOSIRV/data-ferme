-- ================================================================
-- Migration 037 : Types de lot + souche manuelle par lot
-- Dataferme v16.0 - ADOSI
--
-- OBJECTIF :
--   1. Table types_lot : référentiel configurable par l'admin
--      (Poulette, Pondeuse, Poulet de chair, Reproducteur, …)
--   2. Colonne type_lot_id sur lots (FK → types_lot)
--   3. Colonne souche_id_manuel sur lots (FK → souches)
--      → La valeur Tuffigo (souche_id) est conservée intacte.
--        L'affichage et les standards utilisent souche_id_manuel
--        en priorité, souche_id en fallback.
--   4. RPC save_lot_infos : mise à jour par éleveur/technicien/admin
--   5. Mise à jour de v_lots_eleveur avec les nouvelles colonnes
-- ================================================================

-- ----------------------------------------------------------------
-- 1. Table types_lot
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS types_lot (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  nom        text        NOT NULL UNIQUE,
  ordre      int         NOT NULL DEFAULT 0,
  is_active  boolean     NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE types_lot IS 'Référentiel des types de lots avicoles, configurable par l''admin';

-- Index
CREATE INDEX IF NOT EXISTS idx_types_lot_ordre ON types_lot(ordre);

-- Données initiales
INSERT INTO types_lot (nom, ordre) VALUES
  ('Poulette',       1),
  ('Pondeuse',       2),
  ('Poulet de chair',3),
  ('Reproducteur',   4)
ON CONFLICT (nom) DO NOTHING;

-- ----------------------------------------------------------------
-- 2. Nouvelles colonnes sur la table lots
-- ----------------------------------------------------------------
ALTER TABLE lots
  ADD COLUMN IF NOT EXISTS souche_id_manuel uuid REFERENCES souches(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS type_lot_id      uuid REFERENCES types_lot(id) ON DELETE SET NULL;

COMMENT ON COLUMN lots.souche_id       IS 'Souche synchronisée depuis l''API Tuffigo (ne pas modifier)';
COMMENT ON COLUMN lots.souche_id_manuel IS 'Souche choisie manuellement par l''éleveur (priorité sur souche_id pour l''affichage et les standards)';
COMMENT ON COLUMN lots.type_lot_id      IS 'Type de lot : Pondeuse, Poulette, Poulet de chair, etc.';

CREATE INDEX IF NOT EXISTS idx_lots_type_lot      ON lots(type_lot_id);
CREATE INDEX IF NOT EXISTS idx_lots_souche_manuel  ON lots(souche_id_manuel);

-- ----------------------------------------------------------------
-- 3. RLS sur types_lot
--    Pattern identique à types_aliment :
--    lecture libre, écriture permise (custom auth sans JWT Supabase)
-- ----------------------------------------------------------------
ALTER TABLE types_lot ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "types_lot_select" ON types_lot;
CREATE POLICY "types_lot_select" ON types_lot
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "types_lot_insert" ON types_lot;
CREATE POLICY "types_lot_insert" ON types_lot
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "types_lot_update" ON types_lot;
CREATE POLICY "types_lot_update" ON types_lot
  FOR UPDATE USING (true);

DROP POLICY IF EXISTS "types_lot_delete" ON types_lot;
CREATE POLICY "types_lot_delete" ON types_lot
  FOR DELETE USING (true);

-- ----------------------------------------------------------------
-- 4. RPC save_lot_infos
--    Met à jour souche_id_manuel et type_lot_id sur un lot.
--    Rôles autorisés : éleveur (ses propres lots), technicien, admin.
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION save_lot_infos(
  p_user_id         uuid,
  p_lot_id          uuid,
  p_souche_id_manuel uuid DEFAULT NULL,
  p_type_lot_id      uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role       text;
  v_eleveur_id uuid;
  v_lot_exists boolean;
BEGIN
  SET LOCAL row_security = off;

  -- Vérifier l'utilisateur
  SELECT role INTO v_role
  FROM users
  WHERE id = p_user_id AND is_active = true;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Utilisateur introuvable ou inactif';
  END IF;

  IF v_role NOT IN ('admin', 'technicien', 'eleveur') THEN
    RAISE EXCEPTION 'Accès refusé : rôle insuffisant';
  END IF;

  -- Pour un éleveur, vérifier que le lot appartient bien à son exploitation
  IF v_role = 'eleveur' THEN
    SELECT EXISTS (
      SELECT 1
      FROM lots l
      JOIN batiments  bat ON bat.id = l.batiment_id
      JOIN sites      s   ON s.id   = bat.site_id
      JOIN eleveurs   e   ON e.id   = s.eleveur_id
      WHERE l.id = p_lot_id AND e.user_id = p_user_id
    ) INTO v_lot_exists;

    IF NOT v_lot_exists THEN
      RAISE EXCEPTION 'Lot introuvable ou accès refusé';
    END IF;
  ELSE
    -- Technicien / admin : vérifier simplement que le lot existe
    SELECT EXISTS (SELECT 1 FROM lots WHERE id = p_lot_id) INTO v_lot_exists;
    IF NOT v_lot_exists THEN
      RAISE EXCEPTION 'Lot introuvable';
    END IF;
  END IF;

  -- Mise à jour
  UPDATE lots
  SET
    souche_id_manuel = p_souche_id_manuel,
    type_lot_id      = p_type_lot_id,
    updated_at       = now()
  WHERE id = p_lot_id;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION save_lot_infos(uuid, uuid, uuid, uuid)
  TO anon, authenticated;

-- ----------------------------------------------------------------
-- 5. Mise à jour de v_lots_eleveur avec les nouvelles colonnes
-- ----------------------------------------------------------------
DROP VIEW IF EXISTS v_lots_eleveur;
CREATE VIEW v_lots_eleveur AS
SELECT
  l.id,
  l.tuffigo_id,
  l.code_lot,
  l.batiment_id,
  b.nom                                       AS batiment_nom,
  b.site_id,
  s.nom                                       AS site_nom,
  s.eleveur_id,
  e.nom                                       AS eleveur_nom,
  e.prenom                                    AS eleveur_prenom,
  e.code_eleveur,
  l.souche_id,
  l.souche_id_manuel,
  COALESCE(sm.nom, st.nom)                    AS souche_nom_effective,
  sm.nom                                      AS souche_nom_manuel,
  st.nom                                      AS souche_nom_tuffigo,
  l.type_lot_id,
  tl.nom                                      AS type_lot_nom,
  l.effectif_depart,
  l.date_mise_place,
  l.statut,
  CASE
    WHEN l.date_mise_place IS NOT NULL
    THEN EXTRACT(DAY FROM now() - l.date_mise_place)::int
    ELSE NULL
  END                                         AS age_jours,
  l.created_at,
  l.updated_at
FROM lots l
JOIN      batiments  b  ON b.id  = l.batiment_id
JOIN      sites      s  ON s.id  = b.site_id
JOIN      eleveurs   e  ON e.id  = s.eleveur_id
LEFT JOIN souches    sm ON sm.id = l.souche_id_manuel
LEFT JOIN souches    st ON st.id = l.souche_id
LEFT JOIN types_lot  tl ON tl.id = l.type_lot_id;

-- ----------------------------------------------------------------
-- Vérification finale
-- ----------------------------------------------------------------
SELECT 'Migration 037 exécutée avec succès ✅' AS statut;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'lots'
  AND column_name IN ('souche_id_manuel', 'type_lot_id')
ORDER BY column_name;

SELECT nom, ordre, is_active FROM types_lot ORDER BY ordre;
