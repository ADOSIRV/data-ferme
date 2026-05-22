-- ================================================================
-- Patch 031b : Correction save_commande — code_commande manquant
-- Dataferme v16.0 - ADOSI
--
-- PROBLÈME : La migration 031 a réécrit save_commande pour ajouter
-- la traçabilité (created_by_*) mais a oublié de retourner
-- code_commande dans le json_build_object.
-- Résultat : l'email fournisseur affichait "--" au lieu du code
-- (ex: CMD-2026-0001) car le frontend recevait une valeur undefined.
--
-- CORRECTION : Ajouter v_code text dans le DECLARE,
-- récupérer code_commande dans le RETURNING,
-- et l'inclure dans le json retourné.
-- ================================================================

DROP FUNCTION IF EXISTS save_commande(uuid, uuid, uuid, uuid, numeric, text, date, text, uuid, text, uuid, text, text, text);

CREATE FUNCTION save_commande(
  p_user_id                uuid,
  p_eleveur_id             uuid,
  p_type_aliment_id        uuid,
  p_fournisseur_eleveur_id uuid,
  p_quantite               numeric,
  p_unite                  text    DEFAULT 'tonnes',
  p_date_livraison         date    DEFAULT NULL,
  p_notes                  text    DEFAULT NULL,
  p_batiment_id            uuid    DEFAULT NULL,
  p_numero_silo            text    DEFAULT NULL,
  p_lieu_livraison_id      uuid    DEFAULT NULL,
  p_created_by_nom         text    DEFAULT NULL,
  p_created_by_prenom      text    DEFAULT NULL,
  p_created_by_role        text    DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role    text;
  v_nom     text;
  v_prenom  text;
  v_new_id  uuid;
  v_token   text;
  v_code    text;
BEGIN
  SET LOCAL row_security = off;

  -- Récupérer les infos de l'utilisateur connecté
  SELECT role, nom, prenom
    INTO v_role, v_nom, v_prenom
    FROM users
   WHERE id = p_user_id AND is_active = true;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Utilisateur introuvable ou inactif';
  END IF;

  -- Éleveur ET salarié peuvent passer des commandes
  IF v_role NOT IN ('admin', 'technicien', 'eleveur', 'salarie') THEN
    RAISE EXCEPTION 'Accès refusé : rôle insuffisant';
  END IF;

  -- Insérer la commande en traçant l'auteur
  INSERT INTO commandes_aliment (
    eleveur_id, type_aliment_id, fournisseur_eleveur_id,
    quantite, unite, date_livraison_souhaitee, notes,
    batiment_id, numero_silo, lieu_livraison_id,
    created_by_user_id,
    created_by_nom,
    created_by_prenom,
    created_by_role
  )
  VALUES (
    p_eleveur_id, p_type_aliment_id, p_fournisseur_eleveur_id,
    p_quantite, p_unite, p_date_livraison, p_notes,
    p_batiment_id, p_numero_silo, p_lieu_livraison_id,
    p_user_id,
    COALESCE(p_created_by_nom,    v_nom),
    COALESCE(p_created_by_prenom, v_prenom),
    COALESCE(p_created_by_role,   v_role)
  )
  RETURNING id, confirmation_token, code_commande INTO v_new_id, v_token, v_code;

  RETURN json_build_object(
    'success',            true,
    'id',                 v_new_id,
    'code_commande',      v_code,
    'confirmation_token', v_token
  );
END;
$$;

GRANT EXECUTE ON FUNCTION save_commande(uuid, uuid, uuid, uuid, numeric, text, date, text, uuid, text, uuid, text, text, text)
  TO anon, authenticated;

-- ----------------------------------------------------------------
-- Vérification
-- ----------------------------------------------------------------
SELECT 'Patch 031b appliqué avec succès ✅' AS statut;
