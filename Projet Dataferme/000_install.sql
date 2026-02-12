-- ============================================================================
-- SCRIPT MAÎTRE D'INSTALLATION - SUIVI PRODUCTION AVICOLE
-- ============================================================================
-- 
-- Ce script doit être exécuté dans l'ordre suivant :
-- 
-- 1. 001_create_tables_part1.sql  - Tables principales (users, eleveurs, sites, etc.)
-- 2. 002_create_tables_part2.sql  - Tables de données de production
-- 3. 003_create_tables_part3.sql  - Tables WindToFeed et synchronisation
-- 4. 004_create_views.sql         - Vues pour l'application
-- 5. 005_create_rls_policies.sql  - Politiques de sécurité RLS
-- 6. 006_seed_data.sql            - Données de test (optionnel)
--
-- ============================================================================
-- INSTRUCTIONS POUR SUPABASE
-- ============================================================================
--
-- Option 1 : Via l'interface Supabase
-- -----------------------------------
-- 1. Allez dans votre projet Supabase
-- 2. Cliquez sur "SQL Editor" dans le menu de gauche
-- 3. Cliquez sur "New query"
-- 4. Copiez/collez le contenu de chaque fichier SQL dans l'ordre
-- 5. Exécutez chaque script avec le bouton "Run"
--
-- Option 2 : Via la CLI Supabase
-- ------------------------------
-- supabase db push
-- ou
-- psql -h db.xxxxx.supabase.co -p 5432 -d postgres -U postgres -f 001_create_tables_part1.sql
--
-- ============================================================================
-- ORDRE D'EXÉCUTION
-- ============================================================================

-- Étape 1 : Créer les tables principales
\echo '=== Exécution de 001_create_tables_part1.sql ==='
\i 001_create_tables_part1.sql

-- Étape 2 : Créer les tables de données de production
\echo '=== Exécution de 002_create_tables_part2.sql ==='
\i 002_create_tables_part2.sql

-- Étape 3 : Créer les tables WindToFeed et synchronisation
\echo '=== Exécution de 003_create_tables_part3.sql ==='
\i 003_create_tables_part3.sql

-- Étape 4 : Créer les vues
\echo '=== Exécution de 004_create_views.sql ==='
\i 004_create_views.sql

-- Étape 5 : Créer les politiques RLS
\echo '=== Exécution de 005_create_rls_policies.sql ==='
\i 005_create_rls_policies.sql

-- Étape 6 : Insérer les données de test (optionnel)
\echo '=== Exécution de 006_seed_data.sql ==='
\i 006_seed_data.sql

-- ============================================================================
-- VÉRIFICATION FINALE
-- ============================================================================
\echo ''
\echo '=== INSTALLATION TERMINÉE ==='
\echo ''

-- Lister toutes les tables créées
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

-- Lister toutes les vues créées
SELECT 
    schemaname,
    viewname,
    viewowner
FROM pg_views 
WHERE schemaname = 'public'
ORDER BY viewname;

\echo ''
\echo '=== FIN ==='
