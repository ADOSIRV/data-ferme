-- ============================================================================
-- SCRIPT DE CRÉATION DES POLITIQUES RLS (Row Level Security)
-- Sécurité au niveau des lignes pour Supabase
-- ============================================================================

-- ============================================================================
-- ACTIVATION DE RLS SUR TOUTES LES TABLES
-- ============================================================================

ALTER TABLE api_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE eleveurs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE batiments ENABLE ROW LEVEL SECURITY;
ALTER TABLE regulateurs ENABLE ROW LEVEL SECURITY;
ALTER TABLE souches ENABLE ROW LEVEL SECURITY;
ALTER TABLE standards_poids ENABLE ROW LEVEL SECURITY;
ALTER TABLE standards_mortalite ENABLE ROW LEVEL SECURITY;
ALTER TABLE standards_oeufs ENABLE ROW LEVEL SECURITY;
ALTER TABLE standards_aliment ENABLE ROW LEVEL SECURITY;
ALTER TABLE lots ENABLE ROW LEVEL SECURITY;
ALTER TABLE pre_bandes ENABLE ROW LEVEL SECURITY;
ALTER TABLE donnees_poids ENABLE ROW LEVEL SECURITY;
ALTER TABLE donnees_mortalite ENABLE ROW LEVEL SECURITY;
ALTER TABLE donnees_oeufs ENABLE ROW LEVEL SECURITY;
ALTER TABLE donnees_aliment ENABLE ROW LEVEL SECURITY;
ALTER TABLE donnees_eau ENABLE ROW LEVEL SECURITY;
ALTER TABLE donnees_ambiance ENABLE ROW LEVEL SECURITY;
ALTER TABLE donnees_energie ENABLE ROW LEVEL SECURITY;
ALTER TABLE silos ENABLE ROW LEVEL SECURITY;
ALTER TABLE mesures_silos ENABLE ROW LEVEL SECURITY;
ALTER TABLE compteurs_eau ENABLE ROW LEVEL SECURITY;
ALTER TABLE mesures_compteurs_eau ENABLE ROW LEVEL SECURITY;
ALTER TABLE vannes ENABLE ROW LEVEL SECURITY;
ALTER TABLE mesures_vannes ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- FONCTIONS UTILITAIRES POUR LES POLITIQUES
-- ============================================================================

-- Fonction pour vérifier si l'utilisateur est admin ou technicien
CREATE OR REPLACE FUNCTION is_admin_or_technicien()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'technicien')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour récupérer le rôle de l'utilisateur courant
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS VARCHAR AS $$
DECLARE
    user_role VARCHAR;
BEGIN
    SELECT role INTO user_role FROM users WHERE id = auth.uid();
    RETURN user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour récupérer l'éleveur associé à l'utilisateur courant
CREATE OR REPLACE FUNCTION get_user_eleveur_id()
RETURNS UUID AS $$
DECLARE
    eleveur_id UUID;
BEGIN
    SELECT id INTO eleveur_id FROM eleveurs WHERE user_id = auth.uid();
    RETURN eleveur_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- POLITIQUES POUR API_CONFIG (admin uniquement)
-- ============================================================================

CREATE POLICY "api_config_admin_all" ON api_config
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- ============================================================================
-- POLITIQUES POUR USERS
-- ============================================================================

-- Les admins voient tous les utilisateurs
CREATE POLICY "users_admin_select" ON users
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = auth.uid() 
            AND u.role = 'admin'
        )
    );

-- Chaque utilisateur peut voir son propre profil
CREATE POLICY "users_own_select" ON users
    FOR SELECT
    USING (id = auth.uid());

-- Chaque utilisateur peut modifier son propre profil
CREATE POLICY "users_own_update" ON users
    FOR UPDATE
    USING (id = auth.uid());

-- Seuls les admins peuvent créer des utilisateurs
CREATE POLICY "users_admin_insert" ON users
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = auth.uid() 
            AND u.role = 'admin'
        )
    );

-- ============================================================================
-- POLITIQUES POUR ELEVEURS
-- ============================================================================

-- Admin et technicien voient tous les éleveurs
CREATE POLICY "eleveurs_admin_tech_select" ON eleveurs
    FOR SELECT
    USING (is_admin_or_technicien());

-- Un éleveur voit uniquement son propre enregistrement
CREATE POLICY "eleveurs_own_select" ON eleveurs
    FOR SELECT
    USING (user_id = auth.uid());

-- Seuls admin et technicien peuvent modifier
CREATE POLICY "eleveurs_admin_tech_all" ON eleveurs
    FOR ALL
    USING (is_admin_or_technicien());

-- ============================================================================
-- POLITIQUES POUR SITES
-- ============================================================================

-- Admin et technicien voient tous les sites
CREATE POLICY "sites_admin_tech_select" ON sites
    FOR SELECT
    USING (is_admin_or_technicien());

-- Un éleveur voit uniquement ses sites
CREATE POLICY "sites_eleveur_select" ON sites
    FOR SELECT
    USING (
        eleveur_id IN (
            SELECT id FROM eleveurs WHERE user_id = auth.uid()
        )
    );

-- Seuls admin et technicien peuvent modifier
CREATE POLICY "sites_admin_tech_all" ON sites
    FOR ALL
    USING (is_admin_or_technicien());

-- ============================================================================
-- POLITIQUES POUR BATIMENTS
-- ============================================================================

-- Admin et technicien voient tous les bâtiments
CREATE POLICY "batiments_admin_tech_select" ON batiments
    FOR SELECT
    USING (is_admin_or_technicien());

-- Un éleveur voit uniquement les bâtiments de ses sites
CREATE POLICY "batiments_eleveur_select" ON batiments
    FOR SELECT
    USING (
        site_id IN (
            SELECT s.id FROM sites s
            JOIN eleveurs e ON s.eleveur_id = e.id
            WHERE e.user_id = auth.uid()
        )
    );

-- Seuls admin et technicien peuvent modifier
CREATE POLICY "batiments_admin_tech_all" ON batiments
    FOR ALL
    USING (is_admin_or_technicien());

-- ============================================================================
-- POLITIQUES POUR REGULATEURS
-- ============================================================================

-- Admin et technicien voient tous les régulateurs
CREATE POLICY "regulateurs_admin_tech_select" ON regulateurs
    FOR SELECT
    USING (is_admin_or_technicien());

-- Un éleveur voit uniquement les régulateurs de ses bâtiments
CREATE POLICY "regulateurs_eleveur_select" ON regulateurs
    FOR SELECT
    USING (
        batiment_id IN (
            SELECT b.id FROM batiments b
            JOIN sites s ON b.site_id = s.id
            JOIN eleveurs e ON s.eleveur_id = e.id
            WHERE e.user_id = auth.uid()
        )
    );

-- Seuls admin et technicien peuvent modifier
CREATE POLICY "regulateurs_admin_tech_all" ON regulateurs
    FOR ALL
    USING (is_admin_or_technicien());

-- ============================================================================
-- POLITIQUES POUR SOUCHES (lecture pour tous les authentifiés)
-- ============================================================================

CREATE POLICY "souches_select_all" ON souches
    FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- Seuls admin et technicien peuvent modifier les souches
CREATE POLICY "souches_admin_tech_all" ON souches
    FOR ALL
    USING (is_admin_or_technicien());

-- ============================================================================
-- POLITIQUES POUR STANDARDS_* (lecture pour tous les authentifiés)
-- ============================================================================

-- Standards Poids
CREATE POLICY "standards_poids_select_all" ON standards_poids
    FOR SELECT
    USING (auth.uid() IS NOT NULL);

CREATE POLICY "standards_poids_admin_tech_all" ON standards_poids
    FOR ALL
    USING (is_admin_or_technicien());

-- Standards Mortalité
CREATE POLICY "standards_mortalite_select_all" ON standards_mortalite
    FOR SELECT
    USING (auth.uid() IS NOT NULL);

CREATE POLICY "standards_mortalite_admin_tech_all" ON standards_mortalite
    FOR ALL
    USING (is_admin_or_technicien());

-- Standards Œufs
CREATE POLICY "standards_oeufs_select_all" ON standards_oeufs
    FOR SELECT
    USING (auth.uid() IS NOT NULL);

CREATE POLICY "standards_oeufs_admin_tech_all" ON standards_oeufs
    FOR ALL
    USING (is_admin_or_technicien());

-- Standards Aliment
CREATE POLICY "standards_aliment_select_all" ON standards_aliment
    FOR SELECT
    USING (auth.uid() IS NOT NULL);

CREATE POLICY "standards_aliment_admin_tech_all" ON standards_aliment
    FOR ALL
    USING (is_admin_or_technicien());

-- ============================================================================
-- POLITIQUES POUR LOTS
-- ============================================================================

-- Admin et technicien voient tous les lots
CREATE POLICY "lots_admin_tech_select" ON lots
    FOR SELECT
    USING (is_admin_or_technicien());

-- Un éleveur voit uniquement les lots de ses bâtiments
CREATE POLICY "lots_eleveur_select" ON lots
    FOR SELECT
    USING (
        batiment_id IN (
            SELECT b.id FROM batiments b
            JOIN sites s ON b.site_id = s.id
            JOIN eleveurs e ON s.eleveur_id = e.id
            WHERE e.user_id = auth.uid()
        )
    );

-- Seuls admin et technicien peuvent modifier
CREATE POLICY "lots_admin_tech_all" ON lots
    FOR ALL
    USING (is_admin_or_technicien());

-- ============================================================================
-- POLITIQUES POUR PRE_BANDES
-- ============================================================================

-- Admin et technicien voient toutes les pré-bandes
CREATE POLICY "pre_bandes_admin_tech_select" ON pre_bandes
    FOR SELECT
    USING (is_admin_or_technicien());

-- Un éleveur voit uniquement ses pré-bandes
CREATE POLICY "pre_bandes_eleveur_select" ON pre_bandes
    FOR SELECT
    USING (
        eleveur_id IN (
            SELECT id FROM eleveurs WHERE user_id = auth.uid()
        )
    );

-- Seuls admin et technicien peuvent modifier
CREATE POLICY "pre_bandes_admin_tech_all" ON pre_bandes
    FOR ALL
    USING (is_admin_or_technicien());

-- ============================================================================
-- POLITIQUES POUR TOUTES LES TABLES DE DONNÉES (DONNEES_*)
-- ============================================================================

-- Macro pour créer les politiques sur les tables de données
DO $$
DECLARE
    table_name TEXT;
    tables TEXT[] := ARRAY[
        'donnees_poids', 
        'donnees_mortalite', 
        'donnees_oeufs', 
        'donnees_aliment',
        'donnees_eau',
        'donnees_ambiance',
        'donnees_energie'
    ];
BEGIN
    FOREACH table_name IN ARRAY tables
    LOOP
        -- Admin et technicien voient tout
        EXECUTE format('
            CREATE POLICY "%s_admin_tech_select" ON %I
            FOR SELECT
            USING (is_admin_or_technicien());
        ', table_name, table_name);
        
        -- Éleveur voit ses données
        EXECUTE format('
            CREATE POLICY "%s_eleveur_select" ON %I
            FOR SELECT
            USING (
                lot_id IN (
                    SELECT l.id FROM lots l
                    JOIN batiments b ON l.batiment_id = b.id
                    JOIN sites s ON b.site_id = s.id
                    JOIN eleveurs e ON s.eleveur_id = e.id
                    WHERE e.user_id = auth.uid()
                )
            );
        ', table_name, table_name);
        
        -- Seuls admin et technicien peuvent modifier
        EXECUTE format('
            CREATE POLICY "%s_admin_tech_all" ON %I
            FOR ALL
            USING (is_admin_or_technicien());
        ', table_name, table_name);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- POLITIQUES POUR LES TABLES WINDTOFEED
-- ============================================================================

-- SILOS
CREATE POLICY "silos_admin_tech_select" ON silos
    FOR SELECT
    USING (is_admin_or_technicien());

CREATE POLICY "silos_eleveur_select" ON silos
    FOR SELECT
    USING (
        batiment_id IN (
            SELECT b.id FROM batiments b
            JOIN sites s ON b.site_id = s.id
            JOIN eleveurs e ON s.eleveur_id = e.id
            WHERE e.user_id = auth.uid()
        )
    );

CREATE POLICY "silos_admin_tech_all" ON silos
    FOR ALL
    USING (is_admin_or_technicien());

-- MESURES_SILOS
CREATE POLICY "mesures_silos_admin_tech_select" ON mesures_silos
    FOR SELECT
    USING (is_admin_or_technicien());

CREATE POLICY "mesures_silos_eleveur_select" ON mesures_silos
    FOR SELECT
    USING (
        silo_id IN (
            SELECT si.id FROM silos si
            JOIN batiments b ON si.batiment_id = b.id
            JOIN sites s ON b.site_id = s.id
            JOIN eleveurs e ON s.eleveur_id = e.id
            WHERE e.user_id = auth.uid()
        )
    );

CREATE POLICY "mesures_silos_admin_tech_all" ON mesures_silos
    FOR ALL
    USING (is_admin_or_technicien());

-- COMPTEURS_EAU
CREATE POLICY "compteurs_eau_admin_tech_select" ON compteurs_eau
    FOR SELECT
    USING (is_admin_or_technicien());

CREATE POLICY "compteurs_eau_eleveur_select" ON compteurs_eau
    FOR SELECT
    USING (
        batiment_id IN (
            SELECT b.id FROM batiments b
            JOIN sites s ON b.site_id = s.id
            JOIN eleveurs e ON s.eleveur_id = e.id
            WHERE e.user_id = auth.uid()
        )
    );

CREATE POLICY "compteurs_eau_admin_tech_all" ON compteurs_eau
    FOR ALL
    USING (is_admin_or_technicien());

-- MESURES_COMPTEURS_EAU
CREATE POLICY "mesures_compteurs_eau_admin_tech_select" ON mesures_compteurs_eau
    FOR SELECT
    USING (is_admin_or_technicien());

CREATE POLICY "mesures_compteurs_eau_eleveur_select" ON mesures_compteurs_eau
    FOR SELECT
    USING (
        compteur_id IN (
            SELECT ce.id FROM compteurs_eau ce
            JOIN batiments b ON ce.batiment_id = b.id
            JOIN sites s ON b.site_id = s.id
            JOIN eleveurs e ON s.eleveur_id = e.id
            WHERE e.user_id = auth.uid()
        )
    );

CREATE POLICY "mesures_compteurs_eau_admin_tech_all" ON mesures_compteurs_eau
    FOR ALL
    USING (is_admin_or_technicien());

-- VANNES
CREATE POLICY "vannes_admin_tech_select" ON vannes
    FOR SELECT
    USING (is_admin_or_technicien());

CREATE POLICY "vannes_eleveur_select" ON vannes
    FOR SELECT
    USING (
        batiment_id IN (
            SELECT b.id FROM batiments b
            JOIN sites s ON b.site_id = s.id
            JOIN eleveurs e ON s.eleveur_id = e.id
            WHERE e.user_id = auth.uid()
        )
    );

CREATE POLICY "vannes_admin_tech_all" ON vannes
    FOR ALL
    USING (is_admin_or_technicien());

-- MESURES_VANNES
CREATE POLICY "mesures_vannes_admin_tech_select" ON mesures_vannes
    FOR SELECT
    USING (is_admin_or_technicien());

CREATE POLICY "mesures_vannes_eleveur_select" ON mesures_vannes
    FOR SELECT
    USING (
        vanne_id IN (
            SELECT v.id FROM vannes v
            JOIN batiments b ON v.batiment_id = b.id
            JOIN sites s ON b.site_id = s.id
            JOIN eleveurs e ON s.eleveur_id = e.id
            WHERE e.user_id = auth.uid()
        )
    );

CREATE POLICY "mesures_vannes_admin_tech_all" ON mesures_vannes
    FOR ALL
    USING (is_admin_or_technicien());

-- ============================================================================
-- POLITIQUES POUR SYNC_LOGS (admin uniquement)
-- ============================================================================

CREATE POLICY "sync_logs_admin_all" ON sync_logs
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Technicien peut voir les logs en lecture seule
CREATE POLICY "sync_logs_tech_select" ON sync_logs
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'technicien'
        )
    );
