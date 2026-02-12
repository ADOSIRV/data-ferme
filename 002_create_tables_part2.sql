-- ============================================================================
-- SCRIPT DE CRÉATION DE LA BASE DE DONNÉES - PARTIE 2
-- Tables de données de production
-- ============================================================================

-- ============================================================================
-- 14. TABLE DONNEES_POIDS - Mesures de poids
-- ============================================================================
CREATE TABLE donnees_poids (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    lot_id UUID NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
    
    -- Date et âge
    date_mesure DATE NOT NULL,
    jour_age INTEGER NOT NULL CHECK (jour_age >= 0),
    
    -- Poids moyens
    poids_moyen DECIMAL(10, 2) NOT NULL,          -- Poids moyen global (g)
    poids_moyen_male DECIMAL(10, 2),              -- Poids moyen mâles (g)
    poids_moyen_femelle DECIMAL(10, 2),           -- Poids moyen femelles (g)
    
    -- Informations de pesée
    nb_pesees INTEGER,                            -- Nombre de pesées du jour
    nb_pesees_total INTEGER,                      -- Nombre de pesées cumulé
    
    -- Qualité
    homogeneite DECIMAL(5, 2),                    -- Homogénéité (%)
    ecart_type DECIMAL(10, 2),                    -- Écart-type des poids
    
    -- Objectif (de la souche)
    objectif_poids DECIMAL(10, 2),
    
    -- Source des données
    source VARCHAR(20) DEFAULT 'tuffigo' CHECK (source IN ('tuffigo', 'manuel', 'import')),
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité (une mesure par lot et par date)
    CONSTRAINT uq_donnees_poids UNIQUE (lot_id, date_mesure)
);

COMMENT ON TABLE donnees_poids IS 'Mesures de poids journalières - thématique animals_weight de l''API';
COMMENT ON COLUMN donnees_poids.source IS 'tuffigo = synchro API, manuel = saisie utilisateur, import = fichier';

-- Index pour les requêtes fréquentes
CREATE INDEX idx_donnees_poids_lot ON donnees_poids(lot_id);
CREATE INDEX idx_donnees_poids_date ON donnees_poids(date_mesure);
CREATE INDEX idx_donnees_poids_jour ON donnees_poids(jour_age);

-- ============================================================================
-- 15. TABLE DONNEES_MORTALITE - Mesures de mortalité
-- ============================================================================
CREATE TABLE donnees_mortalite (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    lot_id UUID NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
    
    -- Date et âge
    date_mesure DATE NOT NULL,
    jour_age INTEGER NOT NULL CHECK (jour_age >= 0),
    
    -- Mortalité du jour
    nombre_morts INTEGER NOT NULL DEFAULT 0,       -- Total morts du jour
    morts_male INTEGER DEFAULT 0,                  -- Morts mâles
    morts_femelle INTEGER DEFAULT 0,               -- Morts femelles
    morts_mixte INTEGER DEFAULT 0,                 -- Morts non sexés
    
    -- Détail des causes
    morts_elimines INTEGER DEFAULT 0,              -- Éliminés
    morts_malades INTEGER DEFAULT 0,               -- Morts cardiaques/malades
    
    -- Effectif
    effectif_actuel INTEGER,                       -- Effectif restant après mortalité
    
    -- Cumul
    morts_cumul INTEGER,                           -- Total morts depuis début
    taux_mortalite_jour DECIMAL(6, 4),            -- Taux du jour (%)
    taux_mortalite_cumul DECIMAL(6, 4),           -- Taux cumulé (%)
    
    -- Source des données
    source VARCHAR(20) DEFAULT 'tuffigo' CHECK (source IN ('tuffigo', 'manuel', 'import')),
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité
    CONSTRAINT uq_donnees_mortalite UNIQUE (lot_id, date_mesure)
);

COMMENT ON TABLE donnees_mortalite IS 'Mesures de mortalité journalières - thématique animals_mortality de l''API';
COMMENT ON COLUMN donnees_mortalite.morts_elimines IS 'Animaux éliminés (eliminated dans l''API)';
COMMENT ON COLUMN donnees_mortalite.morts_malades IS 'Morts cardiaques (cardiacDeath dans l''API)';

-- Index
CREATE INDEX idx_donnees_mortalite_lot ON donnees_mortalite(lot_id);
CREATE INDEX idx_donnees_mortalite_date ON donnees_mortalite(date_mesure);
CREATE INDEX idx_donnees_mortalite_jour ON donnees_mortalite(jour_age);

-- ============================================================================
-- 16. TABLE DONNEES_OEUFS - Production d'œufs
-- ============================================================================
CREATE TABLE donnees_oeufs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    lot_id UUID NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
    
    -- Date et âge
    date_mesure DATE NOT NULL,
    jour_age INTEGER NOT NULL CHECK (jour_age >= 0),
    
    -- Production
    nombre_oeufs INTEGER NOT NULL,                 -- Nombre d'œufs produits
    oeufs_conformes INTEGER,                       -- Œufs conformes
    oeufs_declasses INTEGER,                       -- Œufs déclassés
    
    -- Taux
    taux_ponte DECIMAL(5, 4),                      -- Taux de ponte (œufs/poule/jour)
    taux_ponte_cumul DECIMAL(5, 4),               -- Taux cumulé
    
    -- Poids des œufs
    poids_moyen_oeuf DECIMAL(6, 2),               -- Poids moyen d'un œuf (g)
    
    -- Source des données
    source VARCHAR(20) DEFAULT 'manuel' CHECK (source IN ('tuffigo', 'manuel', 'import')),
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité
    CONSTRAINT uq_donnees_oeufs UNIQUE (lot_id, date_mesure)
);

COMMENT ON TABLE donnees_oeufs IS 'Production d''œufs journalière';
COMMENT ON COLUMN donnees_oeufs.taux_ponte IS 'Nombre d''œufs / effectif poules présentes';

-- Index
CREATE INDEX idx_donnees_oeufs_lot ON donnees_oeufs(lot_id);
CREATE INDEX idx_donnees_oeufs_date ON donnees_oeufs(date_mesure);
CREATE INDEX idx_donnees_oeufs_jour ON donnees_oeufs(jour_age);

-- ============================================================================
-- 17. TABLE DONNEES_ALIMENT - Consommation d'aliment
-- ============================================================================
CREATE TABLE donnees_aliment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    lot_id UUID NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
    
    -- Date et âge
    date_mesure DATE NOT NULL,
    jour_age INTEGER NOT NULL CHECK (jour_age >= 0),
    
    -- Consommation du jour
    consommation_kg DECIMAL(10, 2) NOT NULL,       -- Consommation totale (kg)
    conso_par_animal DECIMAL(10, 4),               -- Consommation par animal (g)
    
    -- Indices
    indice_conso DECIMAL(6, 3),                    -- Indice de consommation (IC)
    gain_moyen_quotidien DECIMAL(8, 2),           -- GMQ (g/jour)
    
    -- Cumul
    conso_cumul DECIMAL(12, 2),                    -- Consommation cumulée (kg)
    
    -- Type d'aliment
    type_aliment VARCHAR(50),                      -- démarrage, croissance, finition
    
    -- Source des données
    source VARCHAR(20) DEFAULT 'tuffigo' CHECK (source IN ('tuffigo', 'manuel', 'import')),
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité
    CONSTRAINT uq_donnees_aliment UNIQUE (lot_id, date_mesure)
);

COMMENT ON TABLE donnees_aliment IS 'Consommation d''aliment journalière - thématique consumption de l''API';
COMMENT ON COLUMN donnees_aliment.indice_conso IS 'Indice de consommation = kg aliment / kg gain de poids';

-- Index
CREATE INDEX idx_donnees_aliment_lot ON donnees_aliment(lot_id);
CREATE INDEX idx_donnees_aliment_date ON donnees_aliment(date_mesure);
CREATE INDEX idx_donnees_aliment_jour ON donnees_aliment(jour_age);

-- ============================================================================
-- 18. TABLE DONNEES_EAU - Consommation d'eau
-- ============================================================================
CREATE TABLE donnees_eau (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    lot_id UUID NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
    
    -- Date et âge
    date_mesure DATE NOT NULL,
    jour_age INTEGER NOT NULL CHECK (jour_age >= 0),
    
    -- Consommation du jour
    consommation_litres DECIMAL(12, 2) NOT NULL,   -- Consommation totale (L)
    conso_par_animal DECIMAL(10, 4),               -- Consommation par animal (ml)
    
    -- Ratio
    ratio_eau_aliment DECIMAL(6, 3),               -- Ratio eau/aliment
    
    -- Cumul
    conso_cumul DECIMAL(14, 2),                    -- Consommation cumulée (L)
    
    -- Source des données
    source VARCHAR(20) DEFAULT 'tuffigo' CHECK (source IN ('tuffigo', 'manuel', 'import')),
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité
    CONSTRAINT uq_donnees_eau UNIQUE (lot_id, date_mesure)
);

COMMENT ON TABLE donnees_eau IS 'Consommation d''eau journalière - thématique consumption de l''API';
COMMENT ON COLUMN donnees_eau.ratio_eau_aliment IS 'Ratio eau/aliment - indicateur de santé';

-- Index
CREATE INDEX idx_donnees_eau_lot ON donnees_eau(lot_id);
CREATE INDEX idx_donnees_eau_date ON donnees_eau(date_mesure);
CREATE INDEX idx_donnees_eau_jour ON donnees_eau(jour_age);

-- ============================================================================
-- 19. TABLE DONNEES_AMBIANCE - Conditions ambiantes du bâtiment
-- ============================================================================
CREATE TABLE donnees_ambiance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    lot_id UUID NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
    
    -- Date et âge
    date_mesure DATE NOT NULL,
    jour_age INTEGER NOT NULL CHECK (jour_age >= 0),
    
    -- Température
    temperature DECIMAL(5, 2),                     -- Température moyenne (°C)
    temperature_min DECIMAL(5, 2),                 -- Température min
    temperature_max DECIMAL(5, 2),                 -- Température max
    temperature_consigne DECIMAL(5, 2),            -- Température de consigne
    
    -- Hygrométrie
    hygrometrie DECIMAL(5, 2),                     -- Hygrométrie moyenne (%)
    hygrometrie_min DECIMAL(5, 2),
    hygrometrie_max DECIMAL(5, 2),
    
    -- Qualité de l'air
    co2 INTEGER,                                   -- CO2 (ppm)
    ammoniac DECIMAL(6, 2),                        -- Ammoniac (ppm)
    
    -- Ventilation
    debit_ventilation DECIMAL(10, 2),             -- Débit ventilation (m³/h)
    
    -- Source des données
    source VARCHAR(20) DEFAULT 'tuffigo' CHECK (source IN ('tuffigo', 'manuel', 'import')),
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité
    CONSTRAINT uq_donnees_ambiance UNIQUE (lot_id, date_mesure)
);

COMMENT ON TABLE donnees_ambiance IS 'Conditions ambiantes du bâtiment - thématique ambiance de l''API';
COMMENT ON COLUMN donnees_ambiance.temperature IS 'Température moyenne journalière (airTemperatureByProbe)';
COMMENT ON COLUMN donnees_ambiance.hygrometrie IS 'Hygrométrie moyenne journalière (humidityByProbe)';

-- Index
CREATE INDEX idx_donnees_ambiance_lot ON donnees_ambiance(lot_id);
CREATE INDEX idx_donnees_ambiance_date ON donnees_ambiance(date_mesure);
CREATE INDEX idx_donnees_ambiance_jour ON donnees_ambiance(jour_age);

-- ============================================================================
-- 20. TABLE DONNEES_ENERGIE - Consommation énergétique du bâtiment
-- ============================================================================
CREATE TABLE donnees_energie (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    lot_id UUID NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
    
    -- Date et âge
    date_mesure DATE NOT NULL,
    jour_age INTEGER NOT NULL CHECK (jour_age >= 0),
    
    -- Gaz
    gaz_consommation DECIMAL(10, 2),               -- Consommation gaz (m³ ou kWh)
    gaz_unite VARCHAR(10) DEFAULT 'm3',
    
    -- Électricité
    electricite DECIMAL(10, 2),                    -- Consommation électricité (kWh)
    
    -- Ventilation
    vitesse_air DECIMAL(8, 2),                     -- Vitesse d'air (m/s)
    
    -- Chauffage
    temps_chauffage_minutes INTEGER,               -- Temps de chauffage (min)
    
    -- Source des données
    source VARCHAR(20) DEFAULT 'tuffigo' CHECK (source IN ('tuffigo', 'manuel', 'import')),
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité
    CONSTRAINT uq_donnees_energie UNIQUE (lot_id, date_mesure)
);

COMMENT ON TABLE donnees_energie IS 'Consommation énergétique du bâtiment - thématique energy de l''API';

-- Index
CREATE INDEX idx_donnees_energie_lot ON donnees_energie(lot_id);
CREATE INDEX idx_donnees_energie_date ON donnees_energie(date_mesure);
CREATE INDEX idx_donnees_energie_jour ON donnees_energie(jour_age);
