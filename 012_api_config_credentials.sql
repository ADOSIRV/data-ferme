-- ================================================================
-- Migration 012 : Enrichissement de la table api_config
-- Dataferme v16.4 - ADOSI
--
-- Contexte API Tuffigo Rapidex (https://api.mytuffigorapidex.com) :
--   - Authentification API REST : token statique
--     Header : Authorization: token <api_key>
--   - URL de base : https://api.mytuffigorapidex.com/group/v2/
--   - api_login / api_password : identifiants du portail web Tuffigo
--     (utilisés par N8N pour une éventuelle auth complémentaire
--      et stockés pour référence opérationnelle)
-- ================================================================

-- ----------------------------------------------------------------
-- 1. Ajout des nouvelles colonnes d'identifiants
-- ----------------------------------------------------------------
ALTER TABLE api_config
  ADD COLUMN IF NOT EXISTS api_login    text,
  ADD COLUMN IF NOT EXISTS api_password text;

-- ----------------------------------------------------------------
-- 2. Correction de l'URL de base par défaut
--    La version 2 de l'API utilise le chemin /group/v2/
-- ----------------------------------------------------------------
ALTER TABLE api_config
  ALTER COLUMN base_url SET DEFAULT 'https://api.mytuffigorapidex.com/group/v2/';

-- Mettre à jour les lignes existantes si elles ont encore l'ancienne valeur
UPDATE api_config
  SET base_url = 'https://api.mytuffigorapidex.com/group/v2/'
  WHERE base_url IN (
    'https://api.mytuffigorapidex.com',
    'https://api.tuffigo.com',
    ''
  ) OR base_url IS NULL;

-- ----------------------------------------------------------------
-- 3. Commentaires de documentation
-- ----------------------------------------------------------------
COMMENT ON COLUMN api_config.api_key      IS 'Token API Tuffigo — Header : Authorization: token <api_key>';
COMMENT ON COLUMN api_config.api_login    IS 'Login portail web Tuffigo Rapidex (non utilisé pour les appels API REST)';
COMMENT ON COLUMN api_config.api_password IS 'Mot de passe portail web Tuffigo Rapidex';
COMMENT ON COLUMN api_config.base_url     IS 'URL de base de l''API REST — https://api.mytuffigorapidex.com/group/v2/';

-- ================================================================
-- FIN DE LA MIGRATION 012
-- ================================================================
