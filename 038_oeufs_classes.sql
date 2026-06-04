-- ================================================================
-- Migration 038 : Colonnes oeufs_classe_a / oeufs_classe_b
--                 + RPC save_donnee_oeufs
-- Dataferme v16.0 - ADOSI
--
-- OBJECTIF :
--   1. Ajouter oeufs_classe_a et oeufs_classe_b sur donnees_oeufs
--   2. RPC save_donnee_oeufs :
--      - Upsert dans donnees_oeufs (by lot_id + jour_age)
--      - Calcule nombre_oeufs = a + b et taux_ponte = total / effectif
--      - Log dans corrections_journalieres (audit)
--      - Rôles : admin, technicien, éleveur (ses lots uniquement)
-- ================================================================

-- ----------------------------------------------------------------
-- 1. Nouvelles colonnes sur donnees_oeufs
-- ----------------------------------------------------------------
ALTER TABLE donnees_oeufs
  ADD COLUMN IF NOT EXISTS oeufs_classe_a integer,
  ADD COLUMN IF NOT EXISTS oeufs_classe_b integer;

COMMENT ON COLUMN donnees_oeufs.oeufs_classe_a IS 'Nombre d''œufs pondus de classe A (conformes commercialisables)';
COMMENT ON COLUMN donnees_oeufs.oeufs_classe_b IS 'Nombre d''œufs pondus de classe B (déclassés)';

-- ----------------------------------------------------------------
-- 2. RPC save_donnee_oeufs
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION save_donnee_oeufs(
  p_user_id     uuid,
  p_lot_id      uuid,
  p_jour_age    integer,
  p_date_mesure date    DEFAULT NULL,
  p_oeufs_a     integer DEFAULT NULL,
  p_oeufs_b     integer DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role        text;
  v_user_nom    text;
  v_user_prenom text;
  v_lot_exists  boolean;
  v_effectif    integer;
  v_a           integer;
  v_b           integer;
  v_total       integer;
  v_taux        numeric;
  v_old_a       integer;
  v_old_b       integer;
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
    IF NOT v_lot_exists THEN
      RAISE EXCEPTION 'Lot introuvable';
    END IF;
  END IF;

  -- Récupérer l'effectif pour calculer le taux de ponte
  SELECT effectif_depart INTO v_effectif
    FROM lots WHERE id = p_lot_id;

  -- Normaliser les valeurs (NULL → 0 pour le calcul)
  v_a     := COALESCE(p_oeufs_a, 0);
  v_b     := COALESCE(p_oeufs_b, 0);
  v_total := v_a + v_b;
  v_taux  := CASE WHEN COALESCE(v_effectif, 0) > 0
                  THEN v_total::numeric / v_effectif
                  ELSE NULL
             END;

  -- Récupérer les anciennes valeurs pour l'audit
  SELECT oeufs_classe_a, oeufs_classe_b
    INTO v_old_a, v_old_b
    FROM donnees_oeufs
   WHERE lot_id = p_lot_id AND jour_age = p_jour_age;

  -- Upsert : UPDATE si la ligne existe, INSERT sinon
  UPDATE donnees_oeufs
  SET
    oeufs_classe_a = v_a,
    oeufs_classe_b = v_b,
    nombre_oeufs   = v_total,
    taux_ponte     = v_taux
  WHERE lot_id = p_lot_id AND jour_age = p_jour_age;

  IF NOT FOUND THEN
    INSERT INTO donnees_oeufs (
      lot_id, jour_age, date_mesure,
      oeufs_classe_a, oeufs_classe_b,
      nombre_oeufs,   taux_ponte
    ) VALUES (
      p_lot_id, p_jour_age, COALESCE(p_date_mesure, CURRENT_DATE),
      v_a, v_b,
      v_total, v_taux
    );
  END IF;

  -- Traçabilité dans corrections_journalieres (audit)
  -- Classe A
  IF v_old_a IS DISTINCT FROM v_a THEN
    -- Désactiver l'éventuelle correction active précédente
    UPDATE corrections_journalieres
    SET actif = false
    WHERE lot_id = p_lot_id AND jour_age = p_jour_age
      AND champ = 'oeufs_classe_a' AND actif = true;

    INSERT INTO corrections_journalieres (
      lot_id, jour_age, champ,
      valeur_originale, valeur_corrigee,
      modifie_par, modifie_par_nom, modifie_par_role, actif
    ) VALUES (
      p_lot_id, p_jour_age, 'oeufs_classe_a',
      CASE WHEN v_old_a IS NOT NULL THEN v_old_a::text ELSE NULL END,
      v_a::text,
      p_user_id,
      COALESCE(NULLIF(TRIM(COALESCE(v_user_prenom,'') || ' ' || COALESCE(v_user_nom,'')), ''), 'Inconnu'),
      v_role,
      true
    );
  END IF;

  -- Classe B
  IF v_old_b IS DISTINCT FROM v_b THEN
    UPDATE corrections_journalieres
    SET actif = false
    WHERE lot_id = p_lot_id AND jour_age = p_jour_age
      AND champ = 'oeufs_classe_b' AND actif = true;

    INSERT INTO corrections_journalieres (
      lot_id, jour_age, champ,
      valeur_originale, valeur_corrigee,
      modifie_par, modifie_par_nom, modifie_par_role, actif
    ) VALUES (
      p_lot_id, p_jour_age, 'oeufs_classe_b',
      CASE WHEN v_old_b IS NOT NULL THEN v_old_b::text ELSE NULL END,
      v_b::text,
      p_user_id,
      COALESCE(NULLIF(TRIM(COALESCE(v_user_prenom,'') || ' ' || COALESCE(v_user_nom,'')), ''), 'Inconnu'),
      v_role,
      true
    );
  END IF;

  RETURN json_build_object(
    'success',        true,
    'jour_age',       p_jour_age,
    'oeufs_classe_a', v_a,
    'oeufs_classe_b', v_b,
    'nombre_oeufs',   v_total,
    'taux_ponte',     v_taux
  );
END;
$$;

GRANT EXECUTE ON FUNCTION save_donnee_oeufs(uuid, uuid, integer, date, integer, integer)
  TO anon, authenticated;

-- ----------------------------------------------------------------
-- Vérification finale
-- ----------------------------------------------------------------
SELECT 'Migration 038 exécutée avec succès ✅' AS statut;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'donnees_oeufs'
  AND column_name IN ('oeufs_classe_a', 'oeufs_classe_b')
ORDER BY column_name;
