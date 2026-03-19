-- ================================================================
-- Migration 011 : Enrichissement de la table types_aliment
-- Dataferme v16.3 - ADOSI
-- Ajoute : code_aliment (unique), categorie, unite
-- ================================================================

-- ----------------------------------------------------------------
-- 1. Ajout des nouvelles colonnes
-- ----------------------------------------------------------------
ALTER TABLE types_aliment
  ADD COLUMN IF NOT EXISTS code_aliment text,
  ADD COLUMN IF NOT EXISTS categorie    text,
  ADD COLUMN IF NOT EXISTS unite        text NOT NULL DEFAULT 'tonnes';

-- ----------------------------------------------------------------
-- 2. Contrainte d'unicité sur le code aliment
--    (les lignes existantes sans code sont laissées NULL pour le moment)
-- ----------------------------------------------------------------
ALTER TABLE types_aliment
  ADD CONSTRAINT uq_types_aliment_code UNIQUE (code_aliment);

-- ----------------------------------------------------------------
-- 3. Mise à jour des données initiales (seed 008)
--    Attribution d'un code et d'une catégorie pour les 5 aliments
--    déjà présents, sans écraser les données métier existantes.
-- ----------------------------------------------------------------
UPDATE types_aliment SET code_aliment = 'ALI-DEM', categorie = 'Démarrage',   unite = 'tonnes' WHERE nom = 'Démarrage'  AND code_aliment IS NULL;
UPDATE types_aliment SET code_aliment = 'ALI-CRO', categorie = 'Croissance',  unite = 'tonnes' WHERE nom = 'Croissance' AND code_aliment IS NULL;
UPDATE types_aliment SET code_aliment = 'ALI-FIN', categorie = 'Finition',    unite = 'tonnes' WHERE nom = 'Finition'   AND code_aliment IS NULL;
UPDATE types_aliment SET code_aliment = 'ALI-PPO', categorie = 'Ponte',       unite = 'tonnes' WHERE nom = 'Pré-ponte'  AND code_aliment IS NULL;
UPDATE types_aliment SET code_aliment = 'ALI-PON', categorie = 'Ponte',       unite = 'tonnes' WHERE nom = 'Ponte'      AND code_aliment IS NULL;

-- ----------------------------------------------------------------
-- 4. Politique RLS admin : déjà en place dans 008 — rien à ajouter
-- ----------------------------------------------------------------

-- ================================================================
-- FIN DE LA MIGRATION 011
-- ================================================================
