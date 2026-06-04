-- ================================================================
-- Migration 039 : Saisies manuelles de journées
-- Dataferme v16.0 - ADOSI
--
-- OBJECTIF :
--   Permettre à l'utilisateur de saisir manuellement les données
--   d'une journée non synchronisée par Tuffigo.
--
--   Architecture choisie : table dédiée car Tuffigo fait des UPSERT
--   sur les tables donnees_* — les données manuelles ne peuvent pas
--   être stockées dans les mêmes tables sans risque d'écrasement.
--
--   Règles métier :
--   - Date ne peut pas être dans le futur
--   - Date de mise en place du lot obligatoire (calcul jour_age)
--   - Saisie manuelle prioritaire sur les données Tuffigo à l'affichage
--   - Si Tuffigo synchronise plus tard la même journée, la saisie
--     manuelle reste prioritaire mais l'outil le signale visuellement
-- ================================================================

-- ----------------------------------------------------------------
-- 1. Table saisies_manuelles_journalieres
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS saisies_manuelles_journalieres (
  id                 uuid         DEFAULT gen_random_uuid() PRIMARY KEY,
  lot_id             uuid         NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
  jour_age           integer      NOT NULL,
  date_mesure        date         NOT NULL,
  -- Mortalité
  nombre_morts       integer,
  -- Poids
  poids_moyen        numeric(8,1),
  gmq                numeric(8,1),
  homogeneite        numeric(5,2),
  -- Aliment
  aliment_animal     numeric(8,1),
  -- Eau
  eau_litres         numeric(10,2),
  eau_animal         numeric(8,3),
  eau_ratio          numeric(8,3),
  -- Œufs (Pondeuse)
  oeufs_classe_a     integer,
  oeufs_classe_b     integer,
  nombre_oeufs       integer,
  taux_ponte         numeric(6,4),
  -- Méta
  created_by_user_id uuid         REFERENCES users(id) ON DELETE SET NULL,
  created_by_nom     text,
  created_by_role    text,
  created_at         timestamptz  NOT NULL DEFAULT now(),
  updated_at         timestamptz  NOT NULL DEFAULT now(),
  -- Un seul enregistrement manuel par lot+date
  UNIQUE(lot_id, date_mesure)
);

COMMENT ON TABLE saisies_manuelles_journalieres IS
  'Journées saisies manuellement quand Tuffigo n''a pas synchronisé les données. Prioritaires sur les données Tuffigo à l''affichage.';

-- Index
CREATE INDEX IF NOT EXISTS idx_saisies_manuelles_lot   ON saisies_manuelles_journalieres(lot_id);
CREATE INDEX IF NOT EXISTS idx_saisies_manuelles_lot_jour ON saisies_manuelles_journalieres(lot_id, jour_age);

-- ----------------------------------------------------------------
-- 2. RLS
-- ----------------------------------------------------------------
ALTER TABLE saisies_manuelles_journalieres ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "saisies_manuelles_select" ON saisies_manuelles_journalieres;
CREATE POLICY "saisies_manuelles_select" ON saisies_manuelles_journalieres
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "saisies_manuelles_insert" ON saisies_manuelles_journalieres;
CREATE POLICY "saisies_manuelles_insert" ON saisies_manuelles_journalieres
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "saisies_manuelles_update" ON saisies_manuelles_journalieres;
CREATE POLICY "saisies_manuelles_update" ON saisies_manuelles_journalieres
  FOR UPDATE USING (true);

DROP POLICY IF EXISTS "saisies_manuelles_delete" ON saisies_manuelles_journalieres;
CREATE POLICY "saisies_manuelles_delete" ON saisies_manuelles_journalieres
  FOR DELETE USING (true);

-- ----------------------------------------------------------------
-- 3. RPC save_saisie_manuelle
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION save_saisie_manuelle(
  p_user_id        uuid,
  p_lot_id         uuid,
  p_date_mesure    date,
  p_nombre_morts   integer  DEFAULT NULL,
  p_poids_moyen    numeric  DEFAULT NULL,
  p_gmq            numeric  DEFAULT NULL,
  p_homogeneite    numeric  DEFAULT NULL,
  p_aliment_animal numeric  DEFAULT NULL,
  p_eau_litres     numeric  DEFAULT NULL,
  p_eau_animal     numeric  DEFAULT NULL,
  p_eau_ratio      numeric  DEFAULT NULL,
  p_oeufs_a        integer  DEFAULT NULL,
  p_oeufs_b        integer  DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role            text;
  v_user_nom        text;
  v_user_prenom     text;
  v_lot_exists      boolean;
  v_date_mise_place date;
  v_effectif        integer;
  v_jour_age        integer;
  v_nb_oeufs        integer;
  v_taux_ponte      numeric;
BEGIN
  SET LOCAL row_security = off;

  -- Vérifier l'utilisateur
  SELECT role, nom, prenom
    INTO v_role, v_user_nom, v_user_prenom
    FROM users
   WHERE id = p_user_id AND is_active = true;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Utilisateur introuvable ou inactif';
  END IF;

  IF v_role NOT IN ('admin', 'technicien', 'eleveur') THEN
    RAISE EXCEPTION 'Accès refusé : rôle insuffisant';
  END IF;

  -- Pour un éleveur : vérifier que le lot lui appartient
  IF v_role = 'eleveur' THEN
    SELECT EXISTS (
      SELECT 1
      FROM lots l
      JOIN batiments bat ON bat.id = l.batiment_id
      JOIN sites     s   ON s.id   = bat.site_id
      JOIN eleveurs  e   ON e.id   = s.eleveur_id
      WHERE l.id = p_lot_id AND e.user_id = p_user_id
    ) INTO v_lot_exists;
    IF NOT v_lot_exists THEN
      RAISE EXCEPTION 'Lot introuvable ou accès refusé';
    END IF;
  ELSE
    SELECT EXISTS (SELECT 1 FROM lots WHERE id = p_lot_id) INTO v_lot_exists;
    IF NOT v_lot_exists THEN RAISE EXCEPTION 'Lot introuvable'; END IF;
  END IF;

  -- Récupérer la date de mise en place et l'effectif
  SELECT date_mise_place, effectif_depart
    INTO v_date_mise_place, v_effectif
    FROM lots WHERE id = p_lot_id;

  IF v_date_mise_place IS NULL THEN
    RAISE EXCEPTION 'Date de mise en place manquante pour ce lot — impossible de calculer le jour d''âge';
  END IF;

  -- Vérifier que la date n'est pas dans le futur
  IF p_date_mesure > CURRENT_DATE THEN
    RAISE EXCEPTION 'Impossible de saisir des données pour une date future';
  END IF;

  -- Calculer le jour d'âge
  v_jour_age := (p_date_mesure - v_date_mise_place)::integer;
  IF v_jour_age < 0 THEN
    RAISE EXCEPTION 'La date saisie est antérieure à la mise en place du lot';
  END IF;

  -- Calculer les totaux œufs
  v_nb_oeufs := COALESCE(p_oeufs_a, 0) + COALESCE(p_oeufs_b, 0);
  v_taux_ponte := CASE WHEN COALESCE(v_effectif, 0) > 0
                       THEN v_nb_oeufs::numeric / v_effectif
                       ELSE NULL
                  END;

  -- Upsert (INSERT ou UPDATE si la même date existe déjà)
  INSERT INTO saisies_manuelles_journalieres (
    lot_id, jour_age, date_mesure,
    nombre_morts, poids_moyen, gmq, homogeneite,
    aliment_animal, eau_litres, eau_animal, eau_ratio,
    oeufs_classe_a, oeufs_classe_b, nombre_oeufs, taux_ponte,
    created_by_user_id, created_by_nom, created_by_role
  ) VALUES (
    p_lot_id, v_jour_age, p_date_mesure,
    p_nombre_morts, p_poids_moyen, p_gmq, p_homogeneite,
    p_aliment_animal, p_eau_litres, p_eau_animal, p_eau_ratio,
    p_oeufs_a, p_oeufs_b,
    CASE WHEN v_nb_oeufs > 0 THEN v_nb_oeufs ELSE NULL END,
    CASE WHEN v_nb_oeufs > 0 THEN v_taux_ponte ELSE NULL END,
    p_user_id,
    COALESCE(NULLIF(TRIM(COALESCE(v_user_prenom,'') || ' ' || COALESCE(v_user_nom,'')), ''), 'Inconnu'),
    v_role
  )
  ON CONFLICT (lot_id, date_mesure) DO UPDATE SET
    jour_age       = EXCLUDED.jour_age,
    nombre_morts   = EXCLUDED.nombre_morts,
    poids_moyen    = EXCLUDED.poids_moyen,
    gmq            = EXCLUDED.gmq,
    homogeneite    = EXCLUDED.homogeneite,
    aliment_animal = EXCLUDED.aliment_animal,
    eau_litres     = EXCLUDED.eau_litres,
    eau_animal     = EXCLUDED.eau_animal,
    eau_ratio      = EXCLUDED.eau_ratio,
    oeufs_classe_a = EXCLUDED.oeufs_classe_a,
    oeufs_classe_b = EXCLUDED.oeufs_classe_b,
    nombre_oeufs   = EXCLUDED.nombre_oeufs,
    taux_ponte     = EXCLUDED.taux_ponte,
    updated_at     = now();

  RETURN json_build_object(
    'success',    true,
    'jour_age',   v_jour_age,
    'date_mesure', p_date_mesure::text
  );
END;
$$;

GRANT EXECUTE ON FUNCTION save_saisie_manuelle(uuid, uuid, date, integer, numeric, numeric, numeric, numeric, numeric, numeric, numeric, integer, integer)
  TO anon, authenticated;

-- ----------------------------------------------------------------
-- Vérification
-- ----------------------------------------------------------------
SELECT 'Migration 039 exécutée avec succès ✅' AS statut;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'saisies_manuelles_journalieres'
ORDER BY ordinal_position;
