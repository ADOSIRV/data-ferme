-- ================================================================
-- Script 031 : Traçabilité créateur de commande
-- Dataferme v16.0 - ADOSI
-- Permet de savoir quel utilisateur (éleveur ou salarié)
-- a passé chaque commande.
-- À exécuter dans Supabase SQL Editor
-- ================================================================

-- ----------------------------------------------------------------
-- 1. Nouvelles colonnes dans commandes_aliment
-- ----------------------------------------------------------------
ALTER TABLE commandes_aliment
  ADD COLUMN IF NOT EXISTS created_by_user_id  uuid,
  ADD COLUMN IF NOT EXISTS created_by_nom      text,
  ADD COLUMN IF NOT EXISTS created_by_prenom   text,
  ADD COLUMN IF NOT EXISTS created_by_role     text;

-- ----------------------------------------------------------------
-- 2. Supprimer les anciennes versions de save_commande
--    (chaque signature différente = fonction différente en PostgreSQL)
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS save_commande(uuid, uuid, uuid, uuid, numeric, text, date, text);
DROP FUNCTION IF EXISTS save_commande(uuid, uuid, uuid, uuid, numeric, text, date, text, uuid, text);
DROP FUNCTION IF EXISTS save_commande(uuid, uuid, uuid, uuid, numeric, text, date, text, uuid, text, uuid);
DROP FUNCTION IF EXISTS save_commande(uuid, uuid, uuid, uuid, numeric, text, date, text, uuid, text, uuid, text, text, text);

-- ----------------------------------------------------------------
-- 3. Nouvelle version de save_commande avec traçabilité créateur
--    + autorisation des salariés à passer des commandes
-- ----------------------------------------------------------------
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
-- 4. Recréer v_planning_commandes avec les colonnes créateur
-- ----------------------------------------------------------------
DROP VIEW IF EXISTS v_planning_commandes;

CREATE VIEW v_planning_commandes AS
SELECT
  c.id,
  c.eleveur_id,
  e.code_eleveur,
  e.nom                                  AS eleveur_nom,
  e.prenom                               AS eleveur_prenom,
  c.fournisseur_eleveur_id,
  f.nom                                  AS fournisseur_nom,
  COALESCE(f.email, e.email_fournisseur) AS email_fournisseur,
  f.contact_nom,
  ta.nom                                 AS type_aliment,
  c.quantite,
  c.unite,
  c.date_livraison_souhaitee,
  c.date_livraison_confirmee,
  c.heure_livraison_confirmee,
  c.statut,
  c.notes,
  c.commentaire_fournisseur,
  c.batiment_id,
  b.nom                                  AS batiment_nom,
  c.numero_silo,
  c.lieu_livraison_id,
  ll.nom                                 AS lieu_livraison_nom,
  ll.qr_token                            AS lieu_qr_token,
  c.code_commande,
  c.livreur_nom,
  c.livreur_prenom,
  c.livreur_societe,
  c.livreur_signature,
  c.date_livraison_reelle,
  c.quantite_reelle,
  c.unite_livraison,
  c.photos_livraison,
  c.created_by_user_id,
  c.created_by_nom,
  c.created_by_prenom,
  c.created_by_role,
  c.email_envoye_at,
  c.confirmation_token,
  c.confirmation_token_expire_at,
  c.created_at,
  c.updated_at
FROM commandes_aliment c
JOIN       eleveurs             e  ON e.id  = c.eleveur_id
LEFT JOIN  fournisseurs_eleveur f  ON f.id  = c.fournisseur_eleveur_id
LEFT JOIN  types_aliment        ta ON ta.id = c.type_aliment_id
LEFT JOIN  batiments            b  ON b.id  = c.batiment_id
LEFT JOIN  lieux_livraison      ll ON ll.id = c.lieu_livraison_id;

-- ----------------------------------------------------------------
-- Vérification
-- ----------------------------------------------------------------
SELECT 'Script 031 exécuté avec succès ✅' AS statut;
SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_name = 'commandes_aliment'
   AND column_name LIKE 'created_by%'
 ORDER BY column_name;
