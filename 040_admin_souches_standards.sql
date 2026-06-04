-- ================================================================
-- Patch 040 : Admin — Gestion souches & standards zootechniques
--             RPCs save_souche, delete_souche, save_standards_batch
-- Dataferme v16.4 - ADOSI
--
-- CONTEXTE :
--   Permet à l'administrateur de gérer la liste des souches
--   avicoles et de saisir pour chaque souche les standards
--   journaliers (min / cible / max) pour :
--     - Poids (g)
--     - Mortalité (%)
--     - Aliment (g/j/animal)
--     - Œufs (taux de ponte, stocké en 0-1)
--     - Eau (consommation L, ratio eau/aliment)
--
--   Règles de protection :
--     - Les souches importées depuis Tuffigo (tuffigo_id IS NOT NULL)
--       ne peuvent pas être modifiées ou supprimées.
--     - Une souche référencée par au moins un lot ne peut pas
--       être supprimée.
--     - save_standards_batch remplace intégralement les standards
--       d'un type pour une souche donnée (DELETE + INSERT).
-- ================================================================

-- ----------------------------------------------------------------
-- 1. RPC save_souche
--    Crée ou met à jour une souche admin (tuffigo_id = NULL).
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION save_souche(
  p_user_id     uuid,
  p_nom         text,
  p_type        text,
  p_description text    DEFAULT NULL,
  p_souche_id   uuid    DEFAULT NULL   -- NULL = création, non-NULL = mise à jour
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role       text;
  v_tuffigo_id integer;
  v_new_id     uuid;
BEGIN
  SET LOCAL row_security = off;

  -- Vérifier l'utilisateur
  SELECT role INTO v_role
    FROM users
   WHERE id = p_user_id AND is_active = true;
  IF v_role IS NULL    THEN RAISE EXCEPTION 'Utilisateur introuvable ou inactif'; END IF;
  IF v_role <> 'admin' THEN RAISE EXCEPTION 'Accès refusé : rôle administrateur requis'; END IF;

  -- Valider les paramètres
  p_nom := TRIM(COALESCE(p_nom, ''));
  IF p_nom = '' THEN RAISE EXCEPTION 'Le nom de la souche est obligatoire'; END IF;
  IF p_type NOT IN ('chair','pondeuse','reproducteur','autre') THEN
    RAISE EXCEPTION 'Type de lot invalide : %. Valeurs acceptées : chair, pondeuse, reproducteur, autre', p_type;
  END IF;

  IF p_souche_id IS NOT NULL THEN
    -- ── Mise à jour ──────────────────────────────────────────────
    SELECT tuffigo_id INTO v_tuffigo_id
      FROM souches WHERE id = p_souche_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Souche introuvable (id = %)', p_souche_id;
    END IF;
    IF v_tuffigo_id IS NOT NULL THEN
      RAISE EXCEPTION 'Les souches importées depuis Tuffigo ne peuvent pas être modifiées manuellement';
    END IF;

    UPDATE souches
       SET nom         = p_nom,
           type        = p_type,
           description = p_description,
           updated_at  = now()
     WHERE id = p_souche_id;

    RETURN json_build_object(
      'success', true,
      'id',      p_souche_id::text,
      'action',  'update',
      'nom',     p_nom
    );

  ELSE
    -- ── Création ─────────────────────────────────────────────────
    INSERT INTO souches (nom, type, description, visibilite)
    VALUES (p_nom, p_type, p_description, 'shared')
    RETURNING id INTO v_new_id;

    RETURN json_build_object(
      'success', true,
      'id',      v_new_id::text,
      'action',  'create',
      'nom',     p_nom
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION save_souche(uuid, text, text, text, uuid)
  TO anon, authenticated;


-- ----------------------------------------------------------------
-- 2. RPC delete_souche
--    Supprime une souche créée manuellement (pas Tuffigo,
--    pas utilisée par un lot actif).
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION delete_souche(
  p_user_id   uuid,
  p_souche_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role        text;
  v_tuffigo_id  integer;
  v_nom         text;
  v_lots_count  bigint;
BEGIN
  SET LOCAL row_security = off;

  -- Vérifier l'utilisateur
  SELECT role INTO v_role
    FROM users
   WHERE id = p_user_id AND is_active = true;
  IF v_role IS NULL    THEN RAISE EXCEPTION 'Utilisateur introuvable ou inactif'; END IF;
  IF v_role <> 'admin' THEN RAISE EXCEPTION 'Accès refusé : rôle administrateur requis'; END IF;

  -- Vérifier la souche
  SELECT tuffigo_id, nom INTO v_tuffigo_id, v_nom
    FROM souches WHERE id = p_souche_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Souche introuvable (id = %)', p_souche_id;
  END IF;
  IF v_tuffigo_id IS NOT NULL THEN
    RAISE EXCEPTION 'Les souches importées depuis Tuffigo ne peuvent pas être supprimées';
  END IF;

  -- Vérifier qu'aucun lot ne l'utilise
  SELECT COUNT(*) INTO v_lots_count FROM lots WHERE souche_id = p_souche_id;
  IF v_lots_count > 0 THEN
    RAISE EXCEPTION 'Cette souche est utilisée par % lot(s) — suppression impossible', v_lots_count;
  END IF;

  -- Supprimer les standards liés (sécurité, même si CASCADE existe)
  DELETE FROM standards_poids     WHERE souche_id = p_souche_id;
  DELETE FROM standards_mortalite WHERE souche_id = p_souche_id;
  DELETE FROM standards_aliment   WHERE souche_id = p_souche_id;
  DELETE FROM standards_oeufs     WHERE souche_id = p_souche_id;
  DELETE FROM standards_eau       WHERE souche_id = p_souche_id;

  -- Supprimer la souche
  DELETE FROM souches WHERE id = p_souche_id;

  RETURN json_build_object(
    'success', true,
    'nom',     v_nom
  );
END;
$$;

GRANT EXECUTE ON FUNCTION delete_souche(uuid, uuid)
  TO anon, authenticated;


-- ----------------------------------------------------------------
-- 3. RPC save_standards_batch
--    Remplace intégralement les standards d'un type pour une souche.
--    Stratégie : DELETE toutes les lignes existantes, puis INSERT
--    les nouvelles avec date_effet = CURRENT_DATE.
--
--    p_type    : 'poids' | 'mortalite' | 'aliment' | 'oeufs' | 'eau'
--
--    Format p_lignes (JSON array) :
--      poids/mortalite/aliment/oeufs :
--        [{"jour_age":0, "min":42, "cible":42, "max":45}, ...]
--        (oeufs : valeurs en 0-1, ex. 0.85 = 85 %)
--      eau :
--        [{"jour_age":0, "cpa_min":0.015, "cpa_max":0.02,
--          "ratio_min":1.5, "ratio_max":2.2,
--          "litres_min":100, "litres_max":200}, ...]
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION save_standards_batch(
  p_user_id   uuid,
  p_souche_id uuid,
  p_type      text,
  p_lignes    jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role  text;
  v_ligne jsonb;
  v_j     integer;
  v_min   numeric;
  v_cible numeric;
  v_max   numeric;
  v_count integer := 0;
BEGIN
  SET LOCAL row_security = off;

  -- Vérifier l'utilisateur
  SELECT role INTO v_role
    FROM users
   WHERE id = p_user_id AND is_active = true;
  IF v_role IS NULL    THEN RAISE EXCEPTION 'Utilisateur introuvable ou inactif'; END IF;
  IF v_role <> 'admin' THEN RAISE EXCEPTION 'Accès refusé : rôle administrateur requis'; END IF;

  -- Valider le type
  IF p_type NOT IN ('poids','mortalite','aliment','oeufs','eau') THEN
    RAISE EXCEPTION 'Type de standard invalide : %. Valeurs acceptées : poids, mortalite, aliment, oeufs, eau', p_type;
  END IF;

  -- Vérifier que la souche existe
  IF NOT EXISTS (SELECT 1 FROM souches WHERE id = p_souche_id) THEN
    RAISE EXCEPTION 'Souche introuvable (id = %)', p_souche_id;
  END IF;

  -- Vérifier que p_lignes est un tableau JSON
  IF jsonb_typeof(p_lignes) <> 'array' THEN
    RAISE EXCEPTION 'p_lignes doit être un tableau JSON';
  END IF;

  -- ── Suppression des standards existants ──────────────────────
  IF    p_type = 'poids'     THEN DELETE FROM standards_poids     WHERE souche_id = p_souche_id;
  ELSIF p_type = 'mortalite' THEN DELETE FROM standards_mortalite WHERE souche_id = p_souche_id;
  ELSIF p_type = 'aliment'   THEN DELETE FROM standards_aliment   WHERE souche_id = p_souche_id;
  ELSIF p_type = 'oeufs'     THEN DELETE FROM standards_oeufs     WHERE souche_id = p_souche_id;
  ELSIF p_type = 'eau'       THEN DELETE FROM standards_eau       WHERE souche_id = p_souche_id;
  END IF;

  -- ── Insertion des nouvelles lignes ───────────────────────────
  FOR v_ligne IN SELECT * FROM jsonb_array_elements(p_lignes) LOOP

    -- Récupérer le jour d'âge (obligatoire)
    v_j := NULLIF(TRIM(COALESCE(v_ligne->>'jour_age', '')), '')::integer;
    CONTINUE WHEN v_j IS NULL OR v_j < 0;

    IF p_type IN ('poids', 'mortalite', 'aliment', 'oeufs') THEN

      v_min   := NULLIF(TRIM(COALESCE(v_ligne->>'min',   '')), '')::numeric;
      v_cible := NULLIF(TRIM(COALESCE(v_ligne->>'cible', '')), '')::numeric;
      v_max   := NULLIF(TRIM(COALESCE(v_ligne->>'max',   '')), '')::numeric;

      IF p_type = 'poids' THEN
        INSERT INTO standards_poids (souche_id, jour_age, poids_min, poids_cible, poids_max, date_effet)
        VALUES (p_souche_id, v_j, v_min, v_cible, v_max, CURRENT_DATE);

      ELSIF p_type = 'mortalite' THEN
        INSERT INTO standards_mortalite (souche_id, jour_age, mortalite_min, mortalite_cible, mortalite_max, date_effet)
        VALUES (p_souche_id, v_j, v_min, v_cible, v_max, CURRENT_DATE);

      ELSIF p_type = 'aliment' THEN
        INSERT INTO standards_aliment (souche_id, jour_age, conso_min, conso_cible, conso_max, date_effet)
        VALUES (p_souche_id, v_j, v_min, v_cible, v_max, CURRENT_DATE);

      ELSIF p_type = 'oeufs' THEN
        -- Valeurs reçues en 0-1 (ex. 0.85 = 85%)
        INSERT INTO standards_oeufs (souche_id, jour_age, taux_ponte_min, taux_ponte_cible, taux_ponte_max, date_effet)
        VALUES (p_souche_id, v_j, v_min, v_cible, v_max, CURRENT_DATE);
      END IF;

    ELSIF p_type = 'eau' THEN
      INSERT INTO standards_eau (
        souche_id, jour_age,
        conso_par_animal_min, conso_par_animal_max,
        ratio_eau_aliment_min, ratio_eau_aliment_max,
        consommation_litres_min, consommation_litres_max
      ) VALUES (
        p_souche_id, v_j,
        NULLIF(TRIM(COALESCE(v_ligne->>'cpa_min',    '')), '')::numeric,
        NULLIF(TRIM(COALESCE(v_ligne->>'cpa_max',    '')), '')::numeric,
        NULLIF(TRIM(COALESCE(v_ligne->>'ratio_min',  '')), '')::numeric,
        NULLIF(TRIM(COALESCE(v_ligne->>'ratio_max',  '')), '')::numeric,
        NULLIF(TRIM(COALESCE(v_ligne->>'litres_min', '')), '')::numeric,
        NULLIF(TRIM(COALESCE(v_ligne->>'litres_max', '')), '')::numeric
      );
    END IF;

    v_count := v_count + 1;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'type',    p_type,
    'lignes',  v_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION save_standards_batch(uuid, uuid, text, jsonb)
  TO anon, authenticated;


-- ----------------------------------------------------------------
-- Vérification
-- ----------------------------------------------------------------
SELECT 'Patch 040 appliqué avec succès ✅' AS statut;

SELECT routine_name, routine_type
  FROM information_schema.routines
 WHERE routine_schema = 'public'
   AND routine_name IN ('save_souche', 'delete_souche', 'save_standards_batch')
 ORDER BY routine_name;
