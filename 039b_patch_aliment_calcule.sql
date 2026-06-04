-- ================================================================
-- Patch 039b : Ajout colonne aliment_global_kg + effectif_present
--              sur saisies_manuelles_journalieres
--              Mise à jour RPC save_saisie_manuelle
-- Dataferme v16.0 - ADOSI
--
-- CONTEXTE :
--   La saisie manuelle doit recevoir la consommation globale d'aliment
--   (en kg pour tout le lot) plutôt que la conso par animal.
--   L'outil calcule ensuite :
--     - aliment_animal (g/j) = aliment_global_kg * 1000 / effectif_present
--     - eau_animal     (L)   = eau_litres / effectif_present
--     - eau_ratio            = eau_litres / aliment_global_kg
--
--   L'effectif présent est passé par le frontend (calculé : effectif_depart
--   − cumul des morts jusqu'à ce jour, toutes sources confondues).
-- ================================================================

-- ----------------------------------------------------------------
-- 1. Nouvelles colonnes
-- ----------------------------------------------------------------
ALTER TABLE saisies_manuelles_journalieres
  ADD COLUMN IF NOT EXISTS aliment_global_kg  numeric(10,2),
  ADD COLUMN IF NOT EXISTS effectif_present   integer;

COMMENT ON COLUMN saisies_manuelles_journalieres.aliment_global_kg IS
  'Consommation totale d''aliment pour le lot ce jour-là (kg) — saisie brute';
COMMENT ON COLUMN saisies_manuelles_journalieres.effectif_present IS
  'Effectif présent utilisé pour le calcul des ratios (effectif_depart − cumul morts)';

-- ----------------------------------------------------------------
-- 2. Remplacement du RPC save_saisie_manuelle
--    Paramètre p_aliment_animal remplacé par p_aliment_global_kg
--    Nouveau paramètre p_effectif_present
--    Les champs aliment_animal, eau_animal, eau_ratio sont calculés
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION save_saisie_manuelle(
  p_user_id          uuid,
  p_lot_id           uuid,
  p_date_mesure      date,
  p_nombre_morts     integer  DEFAULT NULL,
  p_poids_moyen      numeric  DEFAULT NULL,
  p_gmq              numeric  DEFAULT NULL,
  p_homogeneite      numeric  DEFAULT NULL,
  p_aliment_global_kg numeric DEFAULT NULL,   -- consommation totale en kg
  p_effectif_present integer  DEFAULT NULL,   -- effectif présent ce jour
  p_eau_litres       numeric  DEFAULT NULL,
  p_oeufs_a          integer  DEFAULT NULL,
  p_oeufs_b          integer  DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role             text;
  v_user_nom         text;
  v_user_prenom      text;
  v_lot_exists       boolean;
  v_date_mise_place  date;
  v_effectif_depart  integer;
  v_jour_age         integer;
  v_eff              integer;   -- effectif utilisé pour les calculs
  -- Champs calculés
  v_aliment_animal   numeric;
  v_eau_animal       numeric;
  v_eau_ratio        numeric;
  v_nb_oeufs         integer;
  v_taux_ponte       numeric;
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
      SELECT 1 FROM lots l
      JOIN batiments bat ON bat.id = l.batiment_id
      JOIN sites     s   ON s.id   = bat.site_id
      JOIN eleveurs  e   ON e.id   = s.eleveur_id
      WHERE l.id = p_lot_id AND e.user_id = p_user_id
    ) INTO v_lot_exists;
    IF NOT v_lot_exists THEN RAISE EXCEPTION 'Lot introuvable ou accès refusé'; END IF;
  ELSE
    SELECT EXISTS (SELECT 1 FROM lots WHERE id = p_lot_id) INTO v_lot_exists;
    IF NOT v_lot_exists THEN RAISE EXCEPTION 'Lot introuvable'; END IF;
  END IF;

  -- Récupérer la date de mise en place et l'effectif de départ
  SELECT date_mise_place, effectif_depart
    INTO v_date_mise_place, v_effectif_depart
    FROM lots WHERE id = p_lot_id;

  IF v_date_mise_place IS NULL THEN
    RAISE EXCEPTION 'Date de mise en place manquante pour ce lot';
  END IF;
  IF p_date_mesure > CURRENT_DATE THEN
    RAISE EXCEPTION 'Impossible de saisir des données pour une date future';
  END IF;

  -- Calculer le jour d'âge
  v_jour_age := (p_date_mesure - v_date_mise_place)::integer;
  IF v_jour_age < 0 THEN
    RAISE EXCEPTION 'La date saisie est antérieure à la mise en place du lot';
  END IF;

  -- ── Calculs automatiques ──────────────────────────────────────
  -- Effectif à utiliser (passé par le frontend)
  -- Fallback : effectif_depart si non fourni
  v_eff := COALESCE(NULLIF(p_effectif_present, 0), v_effectif_depart, 1);

  -- Aliment par animal (g/j)
  v_aliment_animal := CASE
    WHEN p_aliment_global_kg IS NOT NULL AND v_eff > 0
    THEN ROUND((p_aliment_global_kg * 1000.0 / v_eff)::numeric, 1)
    ELSE NULL
  END;

  -- Eau par animal (L)
  v_eau_animal := CASE
    WHEN p_eau_litres IS NOT NULL AND v_eff > 0
    THEN ROUND((p_eau_litres / v_eff)::numeric, 4)
    ELSE NULL
  END;

  -- Ratio eau/aliment
  v_eau_ratio := CASE
    WHEN p_eau_litres IS NOT NULL AND p_aliment_global_kg IS NOT NULL AND p_aliment_global_kg > 0
    THEN ROUND((p_eau_litres / p_aliment_global_kg)::numeric, 3)
    ELSE NULL
  END;

  -- Œufs
  v_nb_oeufs := COALESCE(p_oeufs_a, 0) + COALESCE(p_oeufs_b, 0);
  v_taux_ponte := CASE
    WHEN COALESCE(v_effectif_depart, 0) > 0
    THEN v_nb_oeufs::numeric / v_effectif_depart
    ELSE NULL
  END;

  -- ── Upsert ────────────────────────────────────────────────────
  INSERT INTO saisies_manuelles_journalieres (
    lot_id, jour_age, date_mesure,
    nombre_morts, poids_moyen, gmq, homogeneite,
    aliment_global_kg, aliment_animal,
    eau_litres, eau_animal, eau_ratio,
    oeufs_classe_a, oeufs_classe_b, nombre_oeufs, taux_ponte,
    effectif_present,
    created_by_user_id, created_by_nom, created_by_role
  ) VALUES (
    p_lot_id, v_jour_age, p_date_mesure,
    p_nombre_morts, p_poids_moyen, p_gmq, p_homogeneite,
    p_aliment_global_kg, v_aliment_animal,
    p_eau_litres, v_eau_animal, v_eau_ratio,
    p_oeufs_a, p_oeufs_b,
    CASE WHEN v_nb_oeufs > 0 THEN v_nb_oeufs ELSE NULL END,
    CASE WHEN v_nb_oeufs > 0 THEN v_taux_ponte ELSE NULL END,
    p_effectif_present,
    p_user_id,
    COALESCE(NULLIF(TRIM(COALESCE(v_user_prenom,'') || ' ' || COALESCE(v_user_nom,'')), ''), 'Inconnu'),
    v_role
  )
  ON CONFLICT (lot_id, date_mesure) DO UPDATE SET
    jour_age          = EXCLUDED.jour_age,
    nombre_morts      = EXCLUDED.nombre_morts,
    poids_moyen       = EXCLUDED.poids_moyen,
    gmq               = EXCLUDED.gmq,
    homogeneite       = EXCLUDED.homogeneite,
    aliment_global_kg = EXCLUDED.aliment_global_kg,
    aliment_animal    = EXCLUDED.aliment_animal,
    eau_litres        = EXCLUDED.eau_litres,
    eau_animal        = EXCLUDED.eau_animal,
    eau_ratio         = EXCLUDED.eau_ratio,
    oeufs_classe_a    = EXCLUDED.oeufs_classe_a,
    oeufs_classe_b    = EXCLUDED.oeufs_classe_b,
    nombre_oeufs      = EXCLUDED.nombre_oeufs,
    taux_ponte        = EXCLUDED.taux_ponte,
    effectif_present  = EXCLUDED.effectif_present,
    updated_at        = now();

  RETURN json_build_object(
    'success',          true,
    'jour_age',         v_jour_age,
    'date_mesure',      p_date_mesure::text,
    'effectif_present', p_effectif_present,
    'aliment_animal',   v_aliment_animal,
    'eau_animal',       v_eau_animal,
    'eau_ratio',        v_eau_ratio
  );
END;
$$;

GRANT EXECUTE ON FUNCTION save_saisie_manuelle(uuid, uuid, date, integer, numeric, numeric, numeric, numeric, integer, numeric, integer, integer)
  TO anon, authenticated;

-- ----------------------------------------------------------------
-- Vérification
-- ----------------------------------------------------------------
SELECT 'Patch 039b appliqué avec succès ✅' AS statut;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'saisies_manuelles_journalieres'
  AND column_name IN ('aliment_global_kg', 'effectif_present', 'aliment_animal', 'eau_animal', 'eau_ratio')
ORDER BY ordinal_position;
