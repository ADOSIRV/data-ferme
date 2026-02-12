-- ============================================================================
-- SCRIPT DE SEED - DONNÉES DE TEST
-- ============================================================================

-- ============================================================================
-- 1. SOUCHES DE RÉFÉRENCE
-- ============================================================================
INSERT INTO souches (nom, type, visibilite, description) VALUES
('ISA Brown', 'pondeuse', 'shared', 'Souche pondeuse brune, excellente productrice d''œufs'),
('Ross 308', 'chair', 'shared', 'Souche de poulet de chair à croissance rapide'),
('Cobb 500', 'chair', 'shared', 'Souche de poulet de chair polyvalente'),
('Hubbard JA57', 'chair', 'shared', 'Souche Label Rouge, croissance lente'),
('Lohmann Brown', 'pondeuse', 'shared', 'Souche pondeuse à haut rendement'),
('Ross 308 AP', 'reproducteur', 'shared', 'Souche reproductrice chair');

-- ============================================================================
-- 2. STANDARDS POIDS POUR ROSS 308 (exemple pour 10 semaines)
-- ============================================================================
DO $$
DECLARE
    souche_ross_id UUID;
    jour INT;
    poids_base DECIMAL;
BEGIN
    SELECT id INTO souche_ross_id FROM souches WHERE nom = 'Ross 308';
    
    FOR jour IN 0..70 LOOP
        poids_base := 42 + (jour * jour * 0.8) + (jour * 20);
        
        INSERT INTO standards_poids (souche_id, jour_age, poids_min, poids_max, poids_cible, date_effet)
        VALUES (
            souche_ross_id,
            jour,
            ROUND(poids_base * 0.92, 0),
            ROUND(poids_base * 1.08, 0),
            ROUND(poids_base, 0),
            CURRENT_DATE
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. STANDARDS MORTALITÉ POUR ROSS 308
-- ============================================================================
DO $$
DECLARE
    souche_ross_id UUID;
    jour INT;
    morta_cumul DECIMAL;
BEGIN
    SELECT id INTO souche_ross_id FROM souches WHERE nom = 'Ross 308';
    
    FOR jour IN 0..70 LOOP
        morta_cumul := (jour / 42.0) * 3.5;
        
        INSERT INTO standards_mortalite (souche_id, jour_age, mortalite_min, mortalite_max, mortalite_cible, date_effet)
        VALUES (
            souche_ross_id,
            jour,
            GREATEST(0, morta_cumul - 1.0),
            morta_cumul + 1.5,
            morta_cumul,
            CURRENT_DATE
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. STANDARDS ALIMENT POUR ROSS 308
-- ============================================================================
DO $$
DECLARE
    souche_ross_id UUID;
    jour INT;
    conso_base DECIMAL;
BEGIN
    SELECT id INTO souche_ross_id FROM souches WHERE nom = 'Ross 308';
    
    FOR jour IN 0..70 LOOP
        conso_base := 10 + (jour * 3.5) + (jour * jour * 0.02);
        
        INSERT INTO standards_aliment (souche_id, jour_age, conso_min, conso_max, conso_cible, date_effet)
        VALUES (
            souche_ross_id,
            jour,
            ROUND(conso_base * 0.90, 1),
            ROUND(conso_base * 1.10, 1),
            ROUND(conso_base, 1),
            CURRENT_DATE
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 5. UTILISATEURS DE TEST
-- ============================================================================
INSERT INTO users (email, password_hash, nom, prenom, role) VALUES
('admin@example.com', 'hash_admin_2024', 'Admin', 'Système', 'admin'),
('tech@example.com', 'hash_tech_2024', 'Technicien', 'Support', 'technicien'),
('jdupont@example.com', 'hash_eleveur1', 'DUPONT', 'Jean-Pierre', 'eleveur'),
('mmartin@example.com', 'hash_eleveur2', 'MARTIN', 'Marie', 'eleveur');

-- ============================================================================
-- 6. ÉLEVEURS DE TEST
-- ============================================================================
INSERT INTO eleveurs (tuffigo_id, code_eleveur, nom, prenom, raison_sociale, email, siret, user_id)
SELECT 
    1001,
    'ELV-2024-0847',
    'DUPONT',
    'Jean-Pierre',
    'EARL Les Volailles du Bocage',
    'jdupont@example.com',
    '12345678901234',
    (SELECT id FROM users WHERE email = 'jdupont@example.com');

INSERT INTO eleveurs (tuffigo_id, code_eleveur, nom, prenom, raison_sociale, email, siret, user_id)
SELECT 
    1002,
    'ELV-2024-0523',
    'MARTIN',
    'Marie',
    'GAEC La Plume Dorée',
    'mmartin@example.com',
    '98765432109876',
    (SELECT id FROM users WHERE email = 'mmartin@example.com');

INSERT INTO eleveurs (tuffigo_id, code_eleveur, nom, prenom, raison_sociale, email, siret)
VALUES (
    1003,
    'ELV-2024-0391',
    'BERNARD',
    'Philippe',
    'SCEA Avicole des Music',
    'pbernard@example.com',
    '55566677788899'
);

-- ============================================================================
-- 7. SITES DE TEST
-- ============================================================================
INSERT INTO sites (tuffigo_id, eleveur_id, nom, adresse, code_postal, ville, departement)
SELECT 
    10011,
    id,
    'Site Principal DUPONT',
    '123 Route de la Ferme',
    '29000',
    'Quimper',
    'Finistère'
FROM eleveurs WHERE code_eleveur = 'ELV-2024-0847';

INSERT INTO sites (tuffigo_id, eleveur_id, nom, adresse, code_postal, ville, departement)
SELECT 
    10021,
    id,
    'Site Principal MARTIN',
    '456 Chemin des Poules',
    '22000',
    'Saint-Brieuc',
    'Côtes-d''Armor'
FROM eleveurs WHERE code_eleveur = 'ELV-2024-0523';

-- ============================================================================
-- 8. BÂTIMENTS DE TEST
-- ============================================================================
INSERT INTO batiments (tuffigo_id, site_id, nom, capacite)
SELECT 
    100111,
    id,
    'Bâtiment A',
    20000
FROM sites WHERE nom = 'Site Principal DUPONT';

INSERT INTO batiments (tuffigo_id, site_id, nom, capacite)
SELECT 
    100112,
    id,
    'Bâtiment B',
    15000
FROM sites WHERE nom = 'Site Principal DUPONT';

INSERT INTO batiments (tuffigo_id, site_id, nom, capacite)
SELECT 
    100211,
    id,
    'Bâtiment 1',
    18000
FROM sites WHERE nom = 'Site Principal MARTIN';

-- ============================================================================
-- 9. LOTS DE TEST
-- ============================================================================
INSERT INTO lots (tuffigo_id, batiment_id, souche_id, code_lot, effectif_depart, effectif_male, effectif_femelle, date_mise_place, statut)
SELECT 
    10011101,
    b.id,
    s.id,
    'LOT-2024-DUP-A01',
    18500,
    9200,
    9300,
    CURRENT_DATE - INTERVAL '35 days',
    'actif'
FROM batiments b, souches s
WHERE b.nom = 'Bâtiment A' AND s.nom = 'Ross 308';

INSERT INTO lots (tuffigo_id, batiment_id, souche_id, code_lot, effectif_depart, effectif_male, effectif_femelle, date_mise_place, statut)
SELECT 
    10021101,
    b.id,
    s.id,
    'LOT-2024-MAR-101',
    16000,
    8000,
    8000,
    CURRENT_DATE - INTERVAL '28 days',
    'actif'
FROM batiments b, souches s
WHERE b.nom = 'Bâtiment 1' AND s.nom = 'Ross 308';

-- ============================================================================
-- 10. DONNÉES DE PRODUCTION POUR LE LOT DUPONT (35 jours)
-- ============================================================================
DO $$
DECLARE
    lot_id_var UUID;
    jour INT;
    date_mesure DATE;
    poids_base DECIMAL;
    morts_jour INT;
    morts_cumul INT := 0;
    effectif_actuel INT := 18500;
    conso_jour DECIMAL;
BEGIN
    SELECT id INTO lot_id_var FROM lots WHERE code_lot = 'LOT-2024-DUP-A01';
    
    FOR jour IN 0..35 LOOP
        date_mesure := (CURRENT_DATE - INTERVAL '35 days' + (jour || ' days')::INTERVAL)::DATE;
        
        -- POIDS
        poids_base := 42 + (jour * jour * 0.8) + (jour * 20);
        INSERT INTO donnees_poids (lot_id, date_mesure, jour_age, poids_moyen, poids_moyen_male, poids_moyen_femelle, homogeneite, source)
        VALUES (
            lot_id_var,
            date_mesure,
            jour,
            ROUND(poids_base * (0.97 + random() * 0.06), 0),
            ROUND(poids_base * 1.05 * (0.97 + random() * 0.06), 0),
            ROUND(poids_base * 0.95 * (0.97 + random() * 0.06), 0),
            ROUND(85 + random() * 10, 1),
            'tuffigo'
        );
        
        -- MORTALITÉ
        morts_jour := FLOOR(random() * 15 + 2)::INT;
        morts_cumul := morts_cumul + morts_jour;
        effectif_actuel := effectif_actuel - morts_jour;
        
        INSERT INTO donnees_mortalite (lot_id, date_mesure, jour_age, nombre_morts, morts_male, morts_femelle, effectif_actuel, morts_cumul, taux_mortalite_cumul, source)
        VALUES (
            lot_id_var,
            date_mesure,
            jour,
            morts_jour,
            FLOOR(morts_jour * 0.52)::INT,
            CEIL(morts_jour * 0.48)::INT,
            effectif_actuel,
            morts_cumul,
            ROUND((morts_cumul::DECIMAL / 18500) * 100, 4),
            'tuffigo'
        );
        
        -- ALIMENT
        conso_jour := (10 + jour * 3.5) * effectif_actuel / 1000;
        INSERT INTO donnees_aliment (lot_id, date_mesure, jour_age, consommation_kg, conso_par_animal, source)
        VALUES (
            lot_id_var,
            date_mesure,
            jour,
            ROUND(conso_jour * (0.95 + random() * 0.1), 1),
            ROUND((10 + jour * 3.5) * (0.95 + random() * 0.1), 1),
            'tuffigo'
        );
        
        -- EAU
        INSERT INTO donnees_eau (lot_id, date_mesure, jour_age, consommation_litres, conso_par_animal, ratio_eau_aliment, source)
        VALUES (
            lot_id_var,
            date_mesure,
            jour,
            ROUND((15 + jour * 6) * effectif_actuel / 1000 * (0.95 + random() * 0.1), 1),
            ROUND((15 + jour * 6) * (0.95 + random() * 0.1), 1),
            ROUND(1.7 + random() * 0.3, 2),
            'tuffigo'
        );
        
        -- AMBIANCE
        INSERT INTO donnees_ambiance (lot_id, date_mesure, jour_age, temperature, hygrometrie, source)
        VALUES (
            lot_id_var,
            date_mesure,
            jour,
            ROUND(GREATEST(20, 33 - jour * 0.3) + (random() - 0.5) * 2, 1),
            ROUND(55 + random() * 15, 1),
            'tuffigo'
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 11. DONNÉES DE PRODUCTION POUR LE LOT MARTIN (28 jours)
-- ============================================================================
DO $$
DECLARE
    lot_id_var UUID;
    jour INT;
    date_mesure DATE;
    poids_base DECIMAL;
    morts_jour INT;
    morts_cumul INT := 0;
    effectif_actuel INT := 16000;
BEGIN
    SELECT id INTO lot_id_var FROM lots WHERE code_lot = 'LOT-2024-MAR-101';
    
    FOR jour IN 0..28 LOOP
        date_mesure := (CURRENT_DATE - INTERVAL '28 days' + (jour || ' days')::INTERVAL)::DATE;
        
        -- POIDS
        poids_base := 42 + (jour * jour * 0.8) + (jour * 20);
        INSERT INTO donnees_poids (lot_id, date_mesure, jour_age, poids_moyen, source)
        VALUES (
            lot_id_var,
            date_mesure,
            jour,
            ROUND(poids_base * (0.97 + random() * 0.06), 0),
            'tuffigo'
        );
        
        -- MORTALITÉ
        morts_jour := FLOOR(random() * 12 + 1)::INT;
        morts_cumul := morts_cumul + morts_jour;
        effectif_actuel := effectif_actuel - morts_jour;
        
        INSERT INTO donnees_mortalite (lot_id, date_mesure, jour_age, nombre_morts, effectif_actuel, morts_cumul, taux_mortalite_cumul, source)
        VALUES (
            lot_id_var,
            date_mesure,
            jour,
            morts_jour,
            effectif_actuel,
            morts_cumul,
            ROUND((morts_cumul::DECIMAL / 16000) * 100, 4),
            'tuffigo'
        );
        
        -- ALIMENT
        INSERT INTO donnees_aliment (lot_id, date_mesure, jour_age, consommation_kg, conso_par_animal, source)
        VALUES (
            lot_id_var,
            date_mesure,
            jour,
            ROUND((10 + jour * 3.5) * effectif_actuel / 1000 * (0.95 + random() * 0.1), 1),
            ROUND((10 + jour * 3.5) * (0.95 + random() * 0.1), 1),
            'tuffigo'
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- VÉRIFICATION DES DONNÉES CRÉÉES
-- ============================================================================
DO $$
DECLARE
    r RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉSUMÉ DES DONNÉES CRÉÉES ===';
    
    FOR r IN 
        SELECT 
            'Utilisateurs' AS entite, COUNT(*) AS nb FROM users
        UNION ALL SELECT 'Éleveurs', COUNT(*) FROM eleveurs
        UNION ALL SELECT 'Sites', COUNT(*) FROM sites
        UNION ALL SELECT 'Bâtiments', COUNT(*) FROM batiments
        UNION ALL SELECT 'Souches', COUNT(*) FROM souches
        UNION ALL SELECT 'Standards poids', COUNT(*) FROM standards_poids
        UNION ALL SELECT 'Lots', COUNT(*) FROM lots
        UNION ALL SELECT 'Données poids', COUNT(*) FROM donnees_poids
        UNION ALL SELECT 'Données mortalité', COUNT(*) FROM donnees_mortalite
        UNION ALL SELECT 'Données aliment', COUNT(*) FROM donnees_aliment
        UNION ALL SELECT 'Données eau', COUNT(*) FROM donnees_eau
        UNION ALL SELECT 'Données ambiance', COUNT(*) FROM donnees_ambiance
    LOOP
        RAISE NOTICE '% : %', r.entite, r.nb;
    END LOOP;
    
    RAISE NOTICE '';
END;
$$ LANGUAGE plpgsql;
