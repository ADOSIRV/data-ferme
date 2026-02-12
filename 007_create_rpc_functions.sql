-- ============================================================================
-- FONCTIONS RPC POUR N8N - SYNCHRONISATION TUFFIGO
-- À exécuter après les scripts de création de tables
-- ============================================================================

-- ============================================================================
-- FONCTION: Récupérer la configuration API active
-- ============================================================================
CREATE OR REPLACE FUNCTION get_api_config()
RETURNS TABLE (
    api_key VARCHAR,
    base_url VARCHAR,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT ac.api_key, ac.base_url, ac.is_active
    FROM api_config ac
    WHERE ac.is_active = true
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FONCTION: Upsert Site depuis Tuffigo
-- ============================================================================
CREATE OR REPLACE FUNCTION upsert_site_from_tuffigo(
    p_tuffigo_id INTEGER,
    p_eleveur_tuffigo_id INTEGER,
    p_nom VARCHAR,
    p_adresse VARCHAR DEFAULT NULL,
    p_code_postal VARCHAR DEFAULT NULL,
    p_ville VARCHAR DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_eleveur_id UUID;
    v_site_id UUID;
BEGIN
    -- Récupérer l'ID de l'éleveur
    SELECT id INTO v_eleveur_id FROM eleveurs WHERE tuffigo_id = p_eleveur_tuffigo_id;
    
    IF v_eleveur_id IS NULL THEN
        RAISE EXCEPTION 'Éleveur avec tuffigo_id % non trouvé', p_eleveur_tuffigo_id;
    END IF;
    
    -- Upsert du site
    INSERT INTO sites (tuffigo_id, eleveur_id, nom, adresse, code_postal, ville, last_sync_at)
    VALUES (p_tuffigo_id, v_eleveur_id, p_nom, p_adresse, p_code_postal, p_ville, NOW())
    ON CONFLICT (tuffigo_id) DO UPDATE SET
        nom = EXCLUDED.nom,
        adresse = COALESCE(EXCLUDED.adresse, sites.adresse),
        code_postal = COALESCE(EXCLUDED.code_postal, sites.code_postal),
        ville = COALESCE(EXCLUDED.ville, sites.ville),
        last_sync_at = NOW(),
        updated_at = NOW()
    RETURNING id INTO v_site_id;
    
    RETURN v_site_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FONCTION: Upsert Bâtiment depuis Tuffigo
-- ============================================================================
CREATE OR REPLACE FUNCTION upsert_batiment_from_tuffigo(
    p_tuffigo_id INTEGER,
    p_site_tuffigo_id INTEGER,
    p_nom VARCHAR,
    p_capacite INTEGER DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_site_id UUID;
    v_batiment_id UUID;
BEGIN
    -- Récupérer l'ID du site
    SELECT id INTO v_site_id FROM sites WHERE tuffigo_id = p_site_tuffigo_id;
    
    IF v_site_id IS NULL THEN
        RAISE EXCEPTION 'Site avec tuffigo_id % non trouvé', p_site_tuffigo_id;
    END IF;
    
    -- Upsert du bâtiment
    INSERT INTO batiments (tuffigo_id, site_id, nom, capacite, last_sync_at)
    VALUES (p_tuffigo_id, v_site_id, p_nom, p_capacite, NOW())
    ON CONFLICT (tuffigo_id) DO UPDATE SET
        nom = EXCLUDED.nom,
        capacite = COALESCE(EXCLUDED.capacite, batiments.capacite),
        last_sync_at = NOW(),
        updated_at = NOW()
    RETURNING id INTO v_batiment_id;
    
    RETURN v_batiment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FONCTION: Upsert Lot depuis Tuffigo
-- ============================================================================
CREATE OR REPLACE FUNCTION upsert_lot_from_tuffigo(
    p_tuffigo_id INTEGER,
    p_batiment_tuffigo_id INTEGER,
    p_souche_tuffigo_id INTEGER DEFAULT NULL,
    p_code_lot VARCHAR DEFAULT NULL,
    p_effectif_depart INTEGER DEFAULT NULL,
    p_effectif_male INTEGER DEFAULT NULL,
    p_effectif_femelle INTEGER DEFAULT NULL,
    p_date_mise_place VARCHAR DEFAULT NULL,
    p_date_sortie_prevue VARCHAR DEFAULT NULL,
    p_couvoir_id VARCHAR DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_batiment_id UUID;
    v_souche_id UUID;
    v_lot_id UUID;
    v_date_mise_place DATE;
    v_date_sortie DATE;
BEGIN
    -- Récupérer l'ID du bâtiment
    SELECT id INTO v_batiment_id FROM batiments WHERE tuffigo_id = p_batiment_tuffigo_id;
    
    IF v_batiment_id IS NULL THEN
        RAISE EXCEPTION 'Bâtiment avec tuffigo_id % non trouvé', p_batiment_tuffigo_id;
    END IF;
    
    -- Récupérer l'ID de la souche (optionnel)
    IF p_souche_tuffigo_id IS NOT NULL THEN
        SELECT id INTO v_souche_id FROM souches WHERE tuffigo_id = p_souche_tuffigo_id;
    END IF;
    
    -- Conversion des dates
    IF p_date_mise_place IS NOT NULL AND p_date_mise_place != '' THEN
        v_date_mise_place := p_date_mise_place::DATE;
    END IF;
    
    IF p_date_sortie_prevue IS NOT NULL AND p_date_sortie_prevue != '' THEN
        v_date_sortie := p_date_sortie_prevue::DATE;
    END IF;
    
    -- Upsert du lot
    INSERT INTO lots (
        tuffigo_id, batiment_id, souche_id, code_lot, 
        effectif_depart, effectif_male, effectif_femelle,
        date_mise_place, date_sortie_prevue, couvoir_id, last_sync_at
    )
    VALUES (
        p_tuffigo_id, v_batiment_id, v_souche_id, 
        COALESCE(p_code_lot, 'TUF-' || p_tuffigo_id),
        p_effectif_depart, p_effectif_male, p_effectif_femelle,
        v_date_mise_place, v_date_sortie, p_couvoir_id, NOW()
    )
    ON CONFLICT (tuffigo_id) DO UPDATE SET
        souche_id = COALESCE(EXCLUDED.souche_id, lots.souche_id),
        code_lot = COALESCE(EXCLUDED.code_lot, lots.code_lot),
        effectif_depart = COALESCE(EXCLUDED.effectif_depart, lots.effectif_depart),
        effectif_male = COALESCE(EXCLUDED.effectif_male, lots.effectif_male),
        effectif_femelle = COALESCE(EXCLUDED.effectif_femelle, lots.effectif_femelle),
        date_mise_place = COALESCE(EXCLUDED.date_mise_place, lots.date_mise_place),
        date_sortie_prevue = COALESCE(EXCLUDED.date_sortie_prevue, lots.date_sortie_prevue),
        couvoir_id = COALESCE(EXCLUDED.couvoir_id, lots.couvoir_id),
        last_sync_at = NOW(),
        updated_at = NOW()
    RETURNING id INTO v_lot_id;
    
    RETURN v_lot_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FONCTION: Upsert Données Poids
-- ============================================================================
CREATE OR REPLACE FUNCTION upsert_donnees_poids(
    p_lot_tuffigo_id INTEGER,
    p_date_mesure DATE,
    p_jour_age INTEGER,
    p_poids_moyen DECIMAL,
    p_poids_moyen_male DECIMAL DEFAULT NULL,
    p_poids_moyen_femelle DECIMAL DEFAULT NULL,
    p_homogeneite DECIMAL DEFAULT NULL,
    p_nb_pesees INTEGER DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_lot_id UUID;
    v_donnee_id UUID;
BEGIN
    SELECT id INTO v_lot_id FROM lots WHERE tuffigo_id = p_lot_tuffigo_id;
    
    IF v_lot_id IS NULL THEN
        RAISE WARNING 'Lot avec tuffigo_id % non trouvé', p_lot_tuffigo_id;
        RETURN NULL;
    END IF;
    
    INSERT INTO donnees_poids (
        lot_id, date_mesure, jour_age, poids_moyen,
        poids_moyen_male, poids_moyen_femelle, homogeneite, nb_pesees, source
    )
    VALUES (
        v_lot_id, p_date_mesure, p_jour_age, p_poids_moyen,
        p_poids_moyen_male, p_poids_moyen_femelle, p_homogeneite, p_nb_pesees, 'tuffigo'
    )
    ON CONFLICT (lot_id, date_mesure) DO UPDATE SET
        jour_age = EXCLUDED.jour_age,
        poids_moyen = EXCLUDED.poids_moyen,
        poids_moyen_male = COALESCE(EXCLUDED.poids_moyen_male, donnees_poids.poids_moyen_male),
        poids_moyen_femelle = COALESCE(EXCLUDED.poids_moyen_femelle, donnees_poids.poids_moyen_femelle),
        homogeneite = COALESCE(EXCLUDED.homogeneite, donnees_poids.homogeneite),
        nb_pesees = COALESCE(EXCLUDED.nb_pesees, donnees_poids.nb_pesees),
        updated_at = NOW()
    RETURNING id INTO v_donnee_id;
    
    RETURN v_donnee_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FONCTION: Upsert Données Mortalité
-- ============================================================================
CREATE OR REPLACE FUNCTION upsert_donnees_mortalite(
    p_lot_tuffigo_id INTEGER,
    p_date_mesure DATE,
    p_jour_age INTEGER,
    p_nombre_morts INTEGER,
    p_morts_male INTEGER DEFAULT NULL,
    p_morts_femelle INTEGER DEFAULT NULL,
    p_morts_elimines INTEGER DEFAULT NULL,
    p_effectif_actuel INTEGER DEFAULT NULL,
    p_taux_mortalite_cumul DECIMAL DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_lot_id UUID;
    v_donnee_id UUID;
BEGIN
    SELECT id INTO v_lot_id FROM lots WHERE tuffigo_id = p_lot_tuffigo_id;
    
    IF v_lot_id IS NULL THEN
        RAISE WARNING 'Lot avec tuffigo_id % non trouvé', p_lot_tuffigo_id;
        RETURN NULL;
    END IF;
    
    INSERT INTO donnees_mortalite (
        lot_id, date_mesure, jour_age, nombre_morts,
        morts_male, morts_femelle, morts_elimines,
        effectif_actuel, taux_mortalite_cumul, source
    )
    VALUES (
        v_lot_id, p_date_mesure, p_jour_age, p_nombre_morts,
        p_morts_male, p_morts_femelle, p_morts_elimines,
        p_effectif_actuel, p_taux_mortalite_cumul, 'tuffigo'
    )
    ON CONFLICT (lot_id, date_mesure) DO UPDATE SET
        jour_age = EXCLUDED.jour_age,
        nombre_morts = EXCLUDED.nombre_morts,
        morts_male = COALESCE(EXCLUDED.morts_male, donnees_mortalite.morts_male),
        morts_femelle = COALESCE(EXCLUDED.morts_femelle, donnees_mortalite.morts_femelle),
        morts_elimines = COALESCE(EXCLUDED.morts_elimines, donnees_mortalite.morts_elimines),
        effectif_actuel = COALESCE(EXCLUDED.effectif_actuel, donnees_mortalite.effectif_actuel),
        taux_mortalite_cumul = COALESCE(EXCLUDED.taux_mortalite_cumul, donnees_mortalite.taux_mortalite_cumul),
        updated_at = NOW()
    RETURNING id INTO v_donnee_id;
    
    RETURN v_donnee_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FONCTION: Upsert Données Aliment
-- ============================================================================
CREATE OR REPLACE FUNCTION upsert_donnees_aliment(
    p_lot_tuffigo_id INTEGER,
    p_date_mesure DATE,
    p_jour_age INTEGER,
    p_consommation_kg DECIMAL,
    p_conso_par_animal DECIMAL DEFAULT NULL,
    p_indice_conso DECIMAL DEFAULT NULL,
    p_conso_cumul DECIMAL DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_lot_id UUID;
    v_donnee_id UUID;
BEGIN
    SELECT id INTO v_lot_id FROM lots WHERE tuffigo_id = p_lot_tuffigo_id;
    
    IF v_lot_id IS NULL THEN
        RETURN NULL;
    END IF;
    
    INSERT INTO donnees_aliment (
        lot_id, date_mesure, jour_age, consommation_kg,
        conso_par_animal, indice_conso, conso_cumul, source
    )
    VALUES (
        v_lot_id, p_date_mesure, p_jour_age, p_consommation_kg,
        p_conso_par_animal, p_indice_conso, p_conso_cumul, 'tuffigo'
    )
    ON CONFLICT (lot_id, date_mesure) DO UPDATE SET
        jour_age = EXCLUDED.jour_age,
        consommation_kg = EXCLUDED.consommation_kg,
        conso_par_animal = COALESCE(EXCLUDED.conso_par_animal, donnees_aliment.conso_par_animal),
        indice_conso = COALESCE(EXCLUDED.indice_conso, donnees_aliment.indice_conso),
        conso_cumul = COALESCE(EXCLUDED.conso_cumul, donnees_aliment.conso_cumul),
        updated_at = NOW()
    RETURNING id INTO v_donnee_id;
    
    RETURN v_donnee_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FONCTION: Upsert Données Eau
-- ============================================================================
CREATE OR REPLACE FUNCTION upsert_donnees_eau(
    p_lot_tuffigo_id INTEGER,
    p_date_mesure DATE,
    p_jour_age INTEGER,
    p_consommation_litres DECIMAL,
    p_conso_par_animal DECIMAL DEFAULT NULL,
    p_ratio_eau_aliment DECIMAL DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_lot_id UUID;
    v_donnee_id UUID;
BEGIN
    SELECT id INTO v_lot_id FROM lots WHERE tuffigo_id = p_lot_tuffigo_id;
    
    IF v_lot_id IS NULL THEN
        RETURN NULL;
    END IF;
    
    INSERT INTO donnees_eau (
        lot_id, date_mesure, jour_age, consommation_litres,
        conso_par_animal, ratio_eau_aliment, source
    )
    VALUES (
        v_lot_id, p_date_mesure, p_jour_age, p_consommation_litres,
        p_conso_par_animal, p_ratio_eau_aliment, 'tuffigo'
    )
    ON CONFLICT (lot_id, date_mesure) DO UPDATE SET
        jour_age = EXCLUDED.jour_age,
        consommation_litres = EXCLUDED.consommation_litres,
        conso_par_animal = COALESCE(EXCLUDED.conso_par_animal, donnees_eau.conso_par_animal),
        ratio_eau_aliment = COALESCE(EXCLUDED.ratio_eau_aliment, donnees_eau.ratio_eau_aliment),
        updated_at = NOW()
    RETURNING id INTO v_donnee_id;
    
    RETURN v_donnee_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FONCTION: Upsert Données Ambiance
-- ============================================================================
CREATE OR REPLACE FUNCTION upsert_donnees_ambiance(
    p_lot_tuffigo_id INTEGER,
    p_date_mesure DATE,
    p_jour_age INTEGER,
    p_temperature DECIMAL DEFAULT NULL,
    p_hygrometrie DECIMAL DEFAULT NULL,
    p_co2 INTEGER DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_lot_id UUID;
    v_donnee_id UUID;
BEGIN
    SELECT id INTO v_lot_id FROM lots WHERE tuffigo_id = p_lot_tuffigo_id;
    
    IF v_lot_id IS NULL THEN
        RETURN NULL;
    END IF;
    
    INSERT INTO donnees_ambiance (
        lot_id, date_mesure, jour_age, temperature, hygrometrie, co2, source
    )
    VALUES (
        v_lot_id, p_date_mesure, p_jour_age, p_temperature, p_hygrometrie, p_co2, 'tuffigo'
    )
    ON CONFLICT (lot_id, date_mesure) DO UPDATE SET
        jour_age = EXCLUDED.jour_age,
        temperature = COALESCE(EXCLUDED.temperature, donnees_ambiance.temperature),
        hygrometrie = COALESCE(EXCLUDED.hygrometrie, donnees_ambiance.hygrometrie),
        co2 = COALESCE(EXCLUDED.co2, donnees_ambiance.co2),
        updated_at = NOW()
    RETURNING id INTO v_donnee_id;
    
    RETURN v_donnee_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FONCTION: Upsert Données Énergie
-- ============================================================================
CREATE OR REPLACE FUNCTION upsert_donnees_energie(
    p_lot_tuffigo_id INTEGER,
    p_date_mesure DATE,
    p_jour_age INTEGER,
    p_gaz_consommation DECIMAL DEFAULT NULL,
    p_electricite DECIMAL DEFAULT NULL,
    p_vitesse_air DECIMAL DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_lot_id UUID;
    v_donnee_id UUID;
BEGIN
    SELECT id INTO v_lot_id FROM lots WHERE tuffigo_id = p_lot_tuffigo_id;
    
    IF v_lot_id IS NULL THEN
        RETURN NULL;
    END IF;
    
    INSERT INTO donnees_energie (
        lot_id, date_mesure, jour_age, gaz_consommation, electricite, vitesse_air, source
    )
    VALUES (
        v_lot_id, p_date_mesure, p_jour_age, p_gaz_consommation, p_electricite, p_vitesse_air, 'tuffigo'
    )
    ON CONFLICT (lot_id, date_mesure) DO UPDATE SET
        jour_age = EXCLUDED.jour_age,
        gaz_consommation = COALESCE(EXCLUDED.gaz_consommation, donnees_energie.gaz_consommation),
        electricite = COALESCE(EXCLUDED.electricite, donnees_energie.electricite),
        vitesse_air = COALESCE(EXCLUDED.vitesse_air, donnees_energie.vitesse_air),
        updated_at = NOW()
    RETURNING id INTO v_donnee_id;
    
    RETURN v_donnee_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FONCTION: Upsert Standard Poids
-- ============================================================================
CREATE OR REPLACE FUNCTION upsert_standard_poids(
    p_souche_tuffigo_id INTEGER,
    p_jour_age INTEGER,
    p_poids_min DECIMAL,
    p_poids_max DECIMAL,
    p_poids_cible DECIMAL DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_souche_id UUID;
    v_standard_id UUID;
BEGIN
    SELECT id INTO v_souche_id FROM souches WHERE tuffigo_id = p_souche_tuffigo_id;
    
    IF v_souche_id IS NULL THEN
        RETURN NULL;
    END IF;
    
    INSERT INTO standards_poids (
        souche_id, jour_age, poids_min, poids_max, poids_cible, date_effet
    )
    VALUES (
        v_souche_id, p_jour_age, p_poids_min, p_poids_max, p_poids_cible, CURRENT_DATE
    )
    ON CONFLICT (souche_id, jour_age, date_effet) DO UPDATE SET
        poids_min = EXCLUDED.poids_min,
        poids_max = EXCLUDED.poids_max,
        poids_cible = COALESCE(EXCLUDED.poids_cible, standards_poids.poids_cible),
        updated_at = NOW()
    RETURNING id INTO v_standard_id;
    
    RETURN v_standard_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FONCTION: Upsert Standard Mortalité
-- ============================================================================
CREATE OR REPLACE FUNCTION upsert_standard_mortalite(
    p_souche_tuffigo_id INTEGER,
    p_jour_age INTEGER,
    p_mortalite_min DECIMAL,
    p_mortalite_max DECIMAL,
    p_mortalite_cible DECIMAL DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_souche_id UUID;
    v_standard_id UUID;
BEGIN
    SELECT id INTO v_souche_id FROM souches WHERE tuffigo_id = p_souche_tuffigo_id;
    
    IF v_souche_id IS NULL THEN
        RETURN NULL;
    END IF;
    
    INSERT INTO standards_mortalite (
        souche_id, jour_age, mortalite_min, mortalite_max, mortalite_cible, date_effet
    )
    VALUES (
        v_souche_id, p_jour_age, p_mortalite_min, p_mortalite_max, p_mortalite_cible, CURRENT_DATE
    )
    ON CONFLICT (souche_id, jour_age, date_effet) DO UPDATE SET
        mortalite_min = EXCLUDED.mortalite_min,
        mortalite_max = EXCLUDED.mortalite_max,
        mortalite_cible = COALESCE(EXCLUDED.mortalite_cible, standards_mortalite.mortalite_cible),
        updated_at = NOW()
    RETURNING id INTO v_standard_id;
    
    RETURN v_standard_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FONCTION: Upsert Standard Aliment
-- ============================================================================
CREATE OR REPLACE FUNCTION upsert_standard_aliment(
    p_souche_tuffigo_id INTEGER,
    p_jour_age INTEGER,
    p_conso_min DECIMAL,
    p_conso_max DECIMAL,
    p_conso_cible DECIMAL DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_souche_id UUID;
    v_standard_id UUID;
BEGIN
    SELECT id INTO v_souche_id FROM souches WHERE tuffigo_id = p_souche_tuffigo_id;
    
    IF v_souche_id IS NULL THEN
        RETURN NULL;
    END IF;
    
    INSERT INTO standards_aliment (
        souche_id, jour_age, conso_min, conso_max, conso_cible, date_effet
    )
    VALUES (
        v_souche_id, p_jour_age, p_conso_min, p_conso_max, p_conso_cible, CURRENT_DATE
    )
    ON CONFLICT (souche_id, jour_age, date_effet) DO UPDATE SET
        conso_min = EXCLUDED.conso_min,
        conso_max = EXCLUDED.conso_max,
        conso_cible = COALESCE(EXCLUDED.conso_cible, standards_aliment.conso_cible),
        updated_at = NOW()
    RETURNING id INTO v_standard_id;
    
    RETURN v_standard_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
