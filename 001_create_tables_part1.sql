-- ============================================================================
-- SCRIPT DE CRÉATION DE LA BASE DE DONNÉES - SUIVI PRODUCTION AVICOLE
-- Compatible Supabase (PostgreSQL)
-- Enrichi avec l'API Tuffigo Rapidex
-- ============================================================================
-- Version: 2.0
-- Date: 2026-01-29
-- ============================================================================

-- Extension pour générer des UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. TABLE API_CONFIG - Configuration de l'API Tuffigo
-- ============================================================================
CREATE TABLE api_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    api_key VARCHAR(255) NOT NULL,
    base_url VARCHAR(255) DEFAULT 'https://api.mytuffigorapidex.com',
    last_sync TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE api_config IS 'Configuration de connexion à l''API Tuffigo Rapidex';
COMMENT ON COLUMN api_config.api_key IS 'Clé API fournie par Tuffigo (à chiffrer via Vault)';

-- ============================================================================
-- 2. TABLE USERS - Utilisateurs de l'application
-- ============================================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100),
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'technicien', 'eleveur')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_login TIMESTAMPTZ
);

COMMENT ON TABLE users IS 'Utilisateurs de l''application (authentification Supabase Auth)';
COMMENT ON COLUMN users.role IS 'Rôle: admin (accès total), technicien (multi-éleveurs), eleveur (ses données uniquement)';

-- Index pour les recherches fréquentes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- ============================================================================
-- 3. TABLE ELEVEURS - Éleveurs (enrichi avec données Tuffigo)
-- ============================================================================
CREATE TABLE eleveurs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identifiants Tuffigo
    tuffigo_id INTEGER UNIQUE,                    -- breeder_id de l'API
    inrae_id VARCHAR(50),                         -- Identifiant national unique
    
    -- Lien utilisateur
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Informations de base
    code_eleveur VARCHAR(20) UNIQUE NOT NULL,     -- Code interne
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100),
    raison_sociale VARCHAR(200),
    
    -- Contact
    telephone VARCHAR(20),
    email VARCHAR(255),
    
    -- Informations légales
    siret VARCHAR(14),
    
    -- Données JSON de l'API
    adresse_json JSONB,                           -- Adresse complète (address API)
    permissions_json JSONB,                       -- Permissions (generalPermissions API)
    
    -- Statut
    statut_tuffigo VARCHAR(20) DEFAULT 'actif',
    is_active BOOLEAN DEFAULT true,
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_sync_at TIMESTAMPTZ
);

COMMENT ON TABLE eleveurs IS 'Éleveurs/Exploitations - synchronisé avec l''API Tuffigo (breeder)';
COMMENT ON COLUMN eleveurs.tuffigo_id IS 'breeder_id de l''API Tuffigo';
COMMENT ON COLUMN eleveurs.inrae_id IS 'Identifiant national unique (peut être le SIRET)';
COMMENT ON COLUMN eleveurs.adresse_json IS 'Format: {"city": "...", "street": "...", "zipCode": "..."}';

-- Index
CREATE INDEX idx_eleveurs_tuffigo_id ON eleveurs(tuffigo_id);
CREATE INDEX idx_eleveurs_user_id ON eleveurs(user_id);
CREATE INDEX idx_eleveurs_code ON eleveurs(code_eleveur);

-- ============================================================================
-- 4. TABLE SITES - Sites d'exploitation (= Élevages Tuffigo)
-- ============================================================================
CREATE TABLE sites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identifiant Tuffigo
    tuffigo_id INTEGER UNIQUE,                    -- breeding_id de l'API
    
    -- Relations
    eleveur_id UUID NOT NULL REFERENCES eleveurs(id) ON DELETE CASCADE,
    
    -- Informations
    nom VARCHAR(100) NOT NULL,
    adresse VARCHAR(255),
    code_postal VARCHAR(10),
    ville VARCHAR(100),
    departement VARCHAR(100),
    
    -- Coordonnées GPS (optionnel)
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    
    -- Statut
    is_active BOOLEAN DEFAULT true,
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_sync_at TIMESTAMPTZ
);

COMMENT ON TABLE sites IS 'Sites d''exploitation - correspond aux "Élevages" (breeding) de l''API Tuffigo';
COMMENT ON COLUMN sites.tuffigo_id IS 'breeding_id de l''API Tuffigo';

-- Index
CREATE INDEX idx_sites_tuffigo_id ON sites(tuffigo_id);
CREATE INDEX idx_sites_eleveur_id ON sites(eleveur_id);

-- ============================================================================
-- 5. TABLE BATIMENTS - Bâtiments d'élevage
-- ============================================================================
CREATE TABLE batiments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identifiant Tuffigo
    tuffigo_id INTEGER UNIQUE,                    -- building_id de l'API
    
    -- Relations
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    
    -- Informations
    nom VARCHAR(50) NOT NULL,
    capacite INTEGER,
    surface_m2 DECIMAL(10, 2),
    
    -- Statut
    is_active BOOLEAN DEFAULT true,
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_sync_at TIMESTAMPTZ
);

COMMENT ON TABLE batiments IS 'Bâtiments d''élevage - correspond aux "Buildings" de l''API Tuffigo';
COMMENT ON COLUMN batiments.tuffigo_id IS 'building_id de l''API Tuffigo';

-- Index
CREATE INDEX idx_batiments_tuffigo_id ON batiments(tuffigo_id);
CREATE INDEX idx_batiments_site_id ON batiments(site_id);

-- ============================================================================
-- 6. TABLE REGULATEURS - Régulateurs Tuffigo connectés
-- ============================================================================
CREATE TABLE regulateurs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identifiant Tuffigo
    tuffigo_id INTEGER UNIQUE,                    -- id du régulateur dans l'API
    
    -- Relations
    batiment_id UUID NOT NULL REFERENCES batiments(id) ON DELETE CASCADE,
    
    -- Informations
    nom VARCHAR(100) NOT NULL,
    type VARCHAR(50),                             -- avitouch, etc.
    version VARCHAR(20),                          -- Version du firmware
    
    -- Dates Tuffigo
    created_at_tuffigo TIMESTAMPTZ,               -- Date création côté Tuffigo
    
    -- Statut
    is_online BOOLEAN DEFAULT false,
    last_seen_at TIMESTAMPTZ,
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_sync_at TIMESTAMPTZ
);

COMMENT ON TABLE regulateurs IS 'Régulateurs Tuffigo connectés aux bâtiments (Avitouch, etc.)';
COMMENT ON COLUMN regulateurs.type IS 'Type de régulateur: avitouch, etc.';

-- Index
CREATE INDEX idx_regulateurs_tuffigo_id ON regulateurs(tuffigo_id);
CREATE INDEX idx_regulateurs_batiment_id ON regulateurs(batiment_id);

-- ============================================================================
-- 7. TABLE SOUCHES - Souches de volailles
-- ============================================================================
CREATE TABLE souches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identifiant Tuffigo
    tuffigo_id INTEGER UNIQUE,                    -- id de la souche dans l'API
    
    -- Informations
    nom VARCHAR(50) UNIQUE NOT NULL,
    type VARCHAR(50),                             -- pondeuse, chair, reproducteur
    visibilite VARCHAR(20) DEFAULT 'private',     -- shared ou private
    description TEXT,
    
    -- Consignes quotidiennes (data.daily de l'API)
    consignes_json JSONB,
    
    -- Dates
    created_at_tuffigo DATE,                      -- Date création côté Tuffigo
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_sync_at TIMESTAMPTZ
);

COMMENT ON TABLE souches IS 'Souches de volailles - synchronisé avec l''API Tuffigo (strains)';
COMMENT ON COLUMN souches.consignes_json IS 'Consignes quotidiennes issues de data.daily de l''API';
COMMENT ON COLUMN souches.visibilite IS 'shared = partagée par Tuffigo, private = créée par le groupement';

-- Index
CREATE INDEX idx_souches_tuffigo_id ON souches(tuffigo_id);
CREATE INDEX idx_souches_nom ON souches(nom);

-- ============================================================================
-- 8. TABLE STANDARDS_POIDS - Standards de poids par souche et jour d'âge
-- ============================================================================
CREATE TABLE standards_poids (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    souche_id UUID NOT NULL REFERENCES souches(id) ON DELETE CASCADE,
    
    -- Données
    jour_age INTEGER NOT NULL CHECK (jour_age >= 0),
    poids_min DECIMAL(10, 2) NOT NULL,            -- Poids minimum (g)
    poids_max DECIMAL(10, 2) NOT NULL,            -- Poids maximum (g)
    poids_cible DECIMAL(10, 2),                   -- Poids cible (g)
    
    -- Historique
    date_effet DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité
    CONSTRAINT uq_standards_poids UNIQUE (souche_id, jour_age, date_effet)
);

COMMENT ON TABLE standards_poids IS 'Standards de poids par souche et jour d''âge';
COMMENT ON COLUMN standards_poids.date_effet IS 'Date d''entrée en vigueur du standard (permet l''historique)';

-- Index
CREATE INDEX idx_standards_poids_souche ON standards_poids(souche_id);
CREATE INDEX idx_standards_poids_jour ON standards_poids(jour_age);

-- ============================================================================
-- 9. TABLE STANDARDS_MORTALITE - Standards de mortalité par souche et jour d'âge
-- ============================================================================
CREATE TABLE standards_mortalite (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    souche_id UUID NOT NULL REFERENCES souches(id) ON DELETE CASCADE,
    
    -- Données
    jour_age INTEGER NOT NULL CHECK (jour_age >= 0),
    mortalite_min DECIMAL(6, 4) NOT NULL,         -- Taux minimum (%)
    mortalite_max DECIMAL(6, 4) NOT NULL,         -- Taux maximum (%)
    mortalite_cible DECIMAL(6, 4),                -- Taux cible (%)
    
    -- Historique
    date_effet DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité
    CONSTRAINT uq_standards_mortalite UNIQUE (souche_id, jour_age, date_effet)
);

COMMENT ON TABLE standards_mortalite IS 'Standards de mortalité cumulée par souche et jour d''âge';

-- Index
CREATE INDEX idx_standards_mortalite_souche ON standards_mortalite(souche_id);
CREATE INDEX idx_standards_mortalite_jour ON standards_mortalite(jour_age);

-- ============================================================================
-- 10. TABLE STANDARDS_OEUFS - Standards de ponte par souche et jour d'âge
-- ============================================================================
CREATE TABLE standards_oeufs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    souche_id UUID NOT NULL REFERENCES souches(id) ON DELETE CASCADE,
    
    -- Données
    jour_age INTEGER NOT NULL CHECK (jour_age >= 0),
    taux_ponte_min DECIMAL(5, 4) NOT NULL,        -- Taux minimum (œufs/poule/jour)
    taux_ponte_max DECIMAL(5, 4) NOT NULL,        -- Taux maximum
    taux_ponte_cible DECIMAL(5, 4),               -- Taux cible
    
    -- Historique
    date_effet DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité
    CONSTRAINT uq_standards_oeufs UNIQUE (souche_id, jour_age, date_effet)
);

COMMENT ON TABLE standards_oeufs IS 'Standards de taux de ponte par souche et jour d''âge';

-- Index
CREATE INDEX idx_standards_oeufs_souche ON standards_oeufs(souche_id);
CREATE INDEX idx_standards_oeufs_jour ON standards_oeufs(jour_age);

-- ============================================================================
-- 11. TABLE STANDARDS_ALIMENT - Standards de consommation par souche et jour d'âge
-- ============================================================================
CREATE TABLE standards_aliment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    souche_id UUID NOT NULL REFERENCES souches(id) ON DELETE CASCADE,
    
    -- Données
    jour_age INTEGER NOT NULL CHECK (jour_age >= 0),
    conso_min DECIMAL(10, 2) NOT NULL,            -- Consommation minimum (g/animal/jour)
    conso_max DECIMAL(10, 2) NOT NULL,            -- Consommation maximum
    conso_cible DECIMAL(10, 2),                   -- Consommation cible
    
    -- Historique
    date_effet DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité
    CONSTRAINT uq_standards_aliment UNIQUE (souche_id, jour_age, date_effet)
);

COMMENT ON TABLE standards_aliment IS 'Standards de consommation d''aliment par souche et jour d''âge';

-- Index
CREATE INDEX idx_standards_aliment_souche ON standards_aliment(souche_id);
CREATE INDEX idx_standards_aliment_jour ON standards_aliment(jour_age);

-- ============================================================================
-- 12. TABLE LOTS - Lots de volailles (= Bandes Tuffigo)
-- ============================================================================
CREATE TABLE lots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identifiant Tuffigo
    tuffigo_id INTEGER UNIQUE,                    -- batch id de l'API
    
    -- Relations
    batiment_id UUID NOT NULL REFERENCES batiments(id) ON DELETE CASCADE,
    souche_id UUID REFERENCES souches(id) ON DELETE SET NULL,
    
    -- Identification
    code_lot VARCHAR(20) UNIQUE NOT NULL,
    
    -- Effectifs
    effectif_depart INTEGER NOT NULL,             -- Total animaux livrés
    effectif_male INTEGER,                        -- Mâles livrés
    effectif_femelle INTEGER,                     -- Femelles livrées
    
    -- Dates
    date_mise_place DATE NOT NULL,                -- entranceDate API
    date_sortie_prevue DATE,                      -- exitDate API
    date_sortie_reelle DATE,
    
    -- Informations complémentaires
    couvoir_id VARCHAR(50),                       -- hatchery_id API
    
    -- Statut
    statut VARCHAR(20) DEFAULT 'actif' CHECK (statut IN ('actif', 'termine', 'archive')),
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_sync_at TIMESTAMPTZ
);

COMMENT ON TABLE lots IS 'Lots de volailles - correspond aux "Bandes" (batch) de l''API Tuffigo';
COMMENT ON COLUMN lots.tuffigo_id IS 'batch id de l''API Tuffigo';
COMMENT ON COLUMN lots.effectif_male IS 'Nombre de mâles livrés (animals[kind=male].delivered)';
COMMENT ON COLUMN lots.effectif_femelle IS 'Nombre de femelles livrées (animals[kind=female].delivered)';

-- Index
CREATE INDEX idx_lots_tuffigo_id ON lots(tuffigo_id);
CREATE INDEX idx_lots_batiment_id ON lots(batiment_id);
CREATE INDEX idx_lots_souche_id ON lots(souche_id);
CREATE INDEX idx_lots_statut ON lots(statut);
CREATE INDEX idx_lots_date_mise_place ON lots(date_mise_place);

-- ============================================================================
-- 13. TABLE PRE_BANDES - Pré-bandes pour préparer les lots
-- ============================================================================
CREATE TABLE pre_bandes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identifiant Tuffigo
    tuffigo_id INTEGER UNIQUE,                    -- presetbatch id de l'API
    
    -- Relations
    eleveur_id UUID NOT NULL REFERENCES eleveurs(id) ON DELETE CASCADE,
    batiment_id UUID REFERENCES batiments(id) ON DELETE SET NULL,
    souche_id UUID REFERENCES souches(id) ON DELETE SET NULL,
    
    -- Informations
    nom VARCHAR(100) NOT NULL,
    
    -- Effectifs prévus
    effectif_male INTEGER,
    effectif_femelle INTEGER,
    
    -- Dates prévues
    date_entree_prevue DATE,
    date_sortie_prevue DATE,
    
    -- Statut
    statut VARCHAR(20) DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'valide', 'converti', 'annule')),
    lot_id UUID REFERENCES lots(id),              -- Lot créé à partir de cette pré-bande
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_sync_at TIMESTAMPTZ
);

COMMENT ON TABLE pre_bandes IS 'Pré-bandes pour préparer les lots (presetbatchs de l''API Tuffigo)';
COMMENT ON COLUMN pre_bandes.lot_id IS 'Référence vers le lot créé si la pré-bande a été convertie';

-- Index
CREATE INDEX idx_pre_bandes_tuffigo_id ON pre_bandes(tuffigo_id);
CREATE INDEX idx_pre_bandes_eleveur_id ON pre_bandes(eleveur_id);
CREATE INDEX idx_pre_bandes_statut ON pre_bandes(statut);
