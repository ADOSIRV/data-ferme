-- ================================================================
-- Migration 010 : Décomposition de l'adresse fournisseur
-- Dataferme v16.2 - ADOSI
-- Remplace la colonne "adresse" (texte libre) par trois colonnes
-- distinctes : rue, code_postal, ville
-- ================================================================

-- ----------------------------------------------------------------
-- 1. Ajouter les nouvelles colonnes
-- ----------------------------------------------------------------
ALTER TABLE fournisseurs_eleveur
  ADD COLUMN IF NOT EXISTS rue          text,
  ADD COLUMN IF NOT EXISTS code_postal  text,
  ADD COLUMN IF NOT EXISTS ville        text;

-- ----------------------------------------------------------------
-- 2. Migrer les données existantes (adresse → rue)
--    On place l'ancienne valeur dans "rue" pour ne rien perdre.
--    L'admin pourra corriger manuellement si nécessaire.
-- ----------------------------------------------------------------
UPDATE fournisseurs_eleveur
  SET rue = adresse
  WHERE adresse IS NOT NULL
    AND rue IS NULL;

-- ----------------------------------------------------------------
-- 3. Supprimer la vue v_planning_commandes qui dépend de "adresse"
--    Elle sera recréée à l'étape 5 avec rue/code_postal/ville
-- ----------------------------------------------------------------
DROP VIEW IF EXISTS v_planning_commandes;

-- ----------------------------------------------------------------
-- 4. Supprimer l'ancienne colonne
-- ----------------------------------------------------------------
ALTER TABLE fournisseurs_eleveur
  DROP COLUMN IF EXISTS adresse;

-- ----------------------------------------------------------------
-- 5. Recréer la vue v_planning_commandes
--    "fournisseur_adresse" est remplacé par trois colonnes distinctes
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW v_planning_commandes AS
SELECT
  c.id,
  c.eleveur_id,
  e.nom                                       AS eleveur_nom,
  e.prenom                                    AS eleveur_prenom,
  e.code_eleveur,
  -- Fournisseur sélectionné sur la commande (priorité) sinon fournisseur par défaut éleveur
  COALESCE(f.email, e.email_fournisseur)      AS email_fournisseur,
  COALESCE(f.nom,   e.nom_fournisseur)        AS nom_fournisseur,
  f.contact_nom                               AS fournisseur_contact,
  f.rue                                       AS fournisseur_rue,
  f.code_postal                               AS fournisseur_code_postal,
  f.ville                                     AS fournisseur_ville,
  f.id                                        AS fournisseur_eleveur_id,
  t.nom                                       AS type_aliment,
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

-- ================================================================
-- FIN DE LA MIGRATION 010
-- ================================================================
