-- ============================================================================
-- SCRIPT DE CRÉATION DE LA BASE DE DONNÉES - PARTIE 3
-- Tables WindToFeed (équipements) et Synchronisation
-- ============================================================================

-- ============================================================================
-- 21. TABLE SILOS - Silos d'aliment (WindToFeed)
-- ============================================================================
CREATE TABLE silos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identifiant Tuffigo
    tuffigo_id INTEGER UNIQUE,
    
    -- Relations
    batiment_id UUID NOT NULL REFERENCES batiments(id) ON DELETE CASCADE,
    
    -- Informations
    nom VARCHAR(100) NOT NULL,
    type VARCHAR(50),                              -- Type de silo
    formule VARCHAR(100),                          -- Formule d'aliment
    capacite_kg DECIMAL(10, 2),                    -- Capacité en kg
    
    -- Statut
    is_active BOOLEAN DEFAULT true,
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_sync_at TIMESTAMPTZ
);

COMMENT ON TABLE silos IS 'Silos d''aliment - WindToFeed de l''API Tuffigo';

-- Index
CREATE INDEX idx_silos_tuffigo_id ON silos(tuffigo_id);
CREATE INDEX idx_silos_batiment_id ON silos(batiment_id);

-- ============================================================================
-- 22. TABLE MESURES_SILOS - Mesures des silos
-- ============================================================================
CREATE TABLE mesures_silos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    silo_id UUID NOT NULL REFERENCES silos(id) ON DELETE CASCADE,
    lot_id UUID REFERENCES lots(id) ON DELETE SET NULL,
    
    -- Date
    date_mesure DATE NOT NULL,
    
    -- Mesures
    quantite_distribuee DECIMAL(10, 2),            -- Quantité distribuée (kg)
    niveau_stock DECIMAL(10, 2),                   -- Niveau de stock (kg)
    humidite DECIMAL(5, 2),                        -- Humidité de l'aliment (%)
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité
    CONSTRAINT uq_mesures_silos UNIQUE (silo_id, date_mesure)
);

COMMENT ON TABLE mesures_silos IS 'Mesures journalières des silos d''aliment';

-- Index
CREATE INDEX idx_mesures_silos_silo ON mesures_silos(silo_id);
CREATE INDEX idx_mesures_silos_lot ON mesures_silos(lot_id);
CREATE INDEX idx_mesures_silos_date ON mesures_silos(date_mesure);

-- ============================================================================
-- 23. TABLE COMPTEURS_EAU - Compteurs d'eau (WindToFeed)
-- ============================================================================
CREATE TABLE compteurs_eau (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identifiant Tuffigo
    tuffigo_id INTEGER UNIQUE,
    
    -- Relations
    batiment_id UUID NOT NULL REFERENCES batiments(id) ON DELETE CASCADE,
    
    -- Informations
    nom VARCHAR(100) NOT NULL,
    type VARCHAR(50),                              -- Type de compteur
    unite VARCHAR(20) DEFAULT 'litres',            -- Unité de mesure
    
    -- Statut
    is_active BOOLEAN DEFAULT true,
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_sync_at TIMESTAMPTZ
);

COMMENT ON TABLE compteurs_eau IS 'Compteurs d''eau - WindToFeed de l''API Tuffigo';

-- Index
CREATE INDEX idx_compteurs_eau_tuffigo_id ON compteurs_eau(tuffigo_id);
CREATE INDEX idx_compteurs_eau_batiment_id ON compteurs_eau(batiment_id);

-- ============================================================================
-- 24. TABLE MESURES_COMPTEURS_EAU - Mesures des compteurs d'eau
-- ============================================================================
CREATE TABLE mesures_compteurs_eau (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    compteur_id UUID NOT NULL REFERENCES compteurs_eau(id) ON DELETE CASCADE,
    lot_id UUID REFERENCES lots(id) ON DELETE SET NULL,
    
    -- Date
    date_mesure DATE NOT NULL,
    
    -- Mesures
    valeur DECIMAL(14, 2),                         -- Valeur du compteur
    consommation DECIMAL(12, 2),                   -- Consommation du jour (L)
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité
    CONSTRAINT uq_mesures_compteurs_eau UNIQUE (compteur_id, date_mesure)
);

COMMENT ON TABLE mesures_compteurs_eau IS 'Mesures journalières des compteurs d''eau';

-- Index
CREATE INDEX idx_mesures_compteurs_eau_compteur ON mesures_compteurs_eau(compteur_id);
CREATE INDEX idx_mesures_compteurs_eau_lot ON mesures_compteurs_eau(lot_id);
CREATE INDEX idx_mesures_compteurs_eau_date ON mesures_compteurs_eau(date_mesure);

-- ============================================================================
-- 25. TABLE VANNES - Vannes d'alimentation (WindToFeed)
-- ============================================================================
CREATE TABLE vannes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identifiant Tuffigo
    tuffigo_id INTEGER UNIQUE,
    
    -- Relations
    batiment_id UUID NOT NULL REFERENCES batiments(id) ON DELETE CASCADE,
    
    -- Informations
    nom VARCHAR(100) NOT NULL,
    room_id VARCHAR(50),                           -- Identifiant de la salle
    animal_kind VARCHAR(20),                       -- male, female, mixed
    
    -- Statut
    is_active BOOLEAN DEFAULT true,
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_sync_at TIMESTAMPTZ
);

COMMENT ON TABLE vannes IS 'Vannes d''alimentation - WindToFeed de l''API Tuffigo';
COMMENT ON COLUMN vannes.animal_kind IS 'Type d''animaux: male, female, mixed';

-- Index
CREATE INDEX idx_vannes_tuffigo_id ON vannes(tuffigo_id);
CREATE INDEX idx_vannes_batiment_id ON vannes(batiment_id);

-- ============================================================================
-- 26. TABLE MESURES_VANNES - Mesures des vannes
-- ============================================================================
CREATE TABLE mesures_vannes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    vanne_id UUID NOT NULL REFERENCES vannes(id) ON DELETE CASCADE,
    lot_id UUID REFERENCES lots(id) ON DELETE SET NULL,
    
    -- Date
    date_mesure DATE NOT NULL,
    
    -- Mesures
    quantite DECIMAL(10, 2),                       -- Quantité distribuée (kg)
    nb_distributions INTEGER,                      -- Nombre de distributions
    
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contrainte d'unicité
    CONSTRAINT uq_mesures_vannes UNIQUE (vanne_id, date_mesure)
);

COMMENT ON TABLE mesures_vannes IS 'Mesures journalières des vannes d''alimentation';

-- Index
CREATE INDEX idx_mesures_vannes_vanne ON mesures_vannes(vanne_id);
CREATE INDEX idx_mesures_vannes_lot ON mesures_vannes(lot_id);
CREATE INDEX idx_mesures_vannes_date ON mesures_vannes(date_mesure);

-- ============================================================================
-- 27. TABLE SYNC_LOGS - Journal de synchronisation avec l'API
-- ============================================================================
CREATE TABLE sync_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Entité concernée
    type_entite VARCHAR(50) NOT NULL,              -- eleveur, site, lot, donnees_poids, etc.
    entite_id UUID,                                -- ID Supabase de l'entité
    tuffigo_id INTEGER,                            -- ID Tuffigo de l'entité
    
    -- Action
    action VARCHAR(20) NOT NULL CHECK (action IN ('create', 'update', 'delete', 'sync')),
    
    -- Résultat
    status VARCHAR(20) NOT NULL CHECK (status IN ('success', 'error', 'partial')),
    error_message TEXT,
    error_details JSONB,
    
    -- Informations de synchronisation
    records_processed INTEGER DEFAULT 0,
    records_created INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    
    -- Timing
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_ms INTEGER,
    
    -- Métadonnées
    synced_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE sync_logs IS 'Journal de synchronisation avec l''API Tuffigo';
COMMENT ON COLUMN sync_logs.type_entite IS 'Type d''entité: eleveur, site, batiment, lot, donnees_poids, etc.';

-- Index
CREATE INDEX idx_sync_logs_type ON sync_logs(type_entite);
CREATE INDEX idx_sync_logs_status ON sync_logs(status);
CREATE INDEX idx_sync_logs_date ON sync_logs(synced_at);
CREATE INDEX idx_sync_logs_entite ON sync_logs(type_entite, entite_id);

-- ============================================================================
-- TRIGGERS POUR LA MISE À JOUR AUTOMATIQUE DE updated_at
-- ============================================================================

-- Fonction de mise à jour de updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Application des triggers sur toutes les tables avec updated_at
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN 
        SELECT table_name 
        FROM information_schema.columns 
        WHERE column_name = 'updated_at' 
        AND table_schema = 'public'
    LOOP
        EXECUTE format('
            DROP TRIGGER IF EXISTS trigger_update_updated_at ON %I;
            CREATE TRIGGER trigger_update_updated_at
            BEFORE UPDATE ON %I
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
        ', t, t);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FONCTION DE CALCUL DU JOUR D'ÂGE
-- ============================================================================
CREATE OR REPLACE FUNCTION calcul_jour_age(
    p_date_mesure DATE,
    p_date_mise_place DATE
)
RETURNS INTEGER AS $$
BEGIN
    RETURN (p_date_mesure - p_date_mise_place);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calcul_jour_age IS 'Calcule le jour d''âge à partir de la date de mesure et de mise en place';

-- ============================================================================
-- FONCTION DE CALCUL DU TAUX DE MORTALITÉ
-- ============================================================================
CREATE OR REPLACE FUNCTION calcul_taux_mortalite(
    p_morts_cumul INTEGER,
    p_effectif_depart INTEGER
)
RETURNS DECIMAL AS $$
BEGIN
    IF p_effectif_depart = 0 OR p_effectif_depart IS NULL THEN
        RETURN 0;
    END IF;
    RETURN ROUND((p_morts_cumul::DECIMAL / p_effectif_depart::DECIMAL) * 100, 4);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calcul_taux_mortalite IS 'Calcule le taux de mortalité cumulé en pourcentage';
