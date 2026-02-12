-- ============================================================================
-- SCRIPT DE CRÉATION DES VUES
-- Vues utiles pour l'application
-- ============================================================================

-- ============================================================================
-- VUE v_lots_eleveur - Liste des lots avec toutes les informations
-- ============================================================================
CREATE OR REPLACE VIEW v_lots_eleveur AS
SELECT 
    -- Lot
    l.id AS lot_id,
    l.tuffigo_id AS lot_tuffigo_id,
    l.code_lot,
    l.effectif_depart,
    l.effectif_male,
    l.effectif_femelle,
    l.date_mise_place,
    l.date_sortie_prevue,
    l.date_sortie_reelle,
    l.statut AS lot_statut,
    l.couvoir_id,
    
    -- Calcul de l'âge
    (CURRENT_DATE - l.date_mise_place) AS age_jours,
    FLOOR((CURRENT_DATE - l.date_mise_place) / 7.0) AS age_semaines,
    
    -- Souche
    so.id AS souche_id,
    so.tuffigo_id AS souche_tuffigo_id,
    so.nom AS souche_nom,
    so.type AS souche_type,
    
    -- Bâtiment
    b.id AS batiment_id,
    b.tuffigo_id AS batiment_tuffigo_id,
    b.nom AS batiment_nom,
    b.capacite AS batiment_capacite,
    
    -- Site
    s.id AS site_id,
    s.tuffigo_id AS site_tuffigo_id,
    s.nom AS site_nom,
    s.ville AS site_ville,
    
    -- Éleveur
    e.id AS eleveur_id,
    e.tuffigo_id AS eleveur_tuffigo_id,
    e.code_eleveur,
    CONCAT(e.nom, ' ', COALESCE(e.prenom, '')) AS eleveur_nom_complet,
    e.raison_sociale
    
FROM lots l
JOIN batiments b ON l.batiment_id = b.id
JOIN sites s ON b.site_id = s.id
JOIN eleveurs e ON s.eleveur_id = e.id
LEFT JOIN souches so ON l.souche_id = so.id
WHERE l.statut != 'archive';

COMMENT ON VIEW v_lots_eleveur IS 'Vue des lots avec informations complètes (bâtiment, site, éleveur, souche)';

-- ============================================================================
-- VUE v_donnees_poids_avec_standards - Poids avec comparaison aux standards
-- ============================================================================
CREATE OR REPLACE VIEW v_donnees_poids_avec_standards AS
SELECT 
    dp.id,
    dp.lot_id,
    l.code_lot,
    l.souche_id,
    dp.date_mesure,
    dp.jour_age,
    dp.poids_moyen,
    dp.poids_moyen_male,
    dp.poids_moyen_femelle,
    dp.homogeneite,
    dp.source,
    
    -- Standards de la souche
    sp.poids_min,
    sp.poids_max,
    sp.poids_cible,
    
    -- Calcul de l'écart par rapport aux standards
    CASE 
        WHEN sp.poids_min IS NULL THEN 'pas_de_standard'
        WHEN dp.poids_moyen < sp.poids_min THEN 'sous_min'
        WHEN dp.poids_moyen > sp.poids_max THEN 'sur_max'
        ELSE 'dans_norme'
    END AS statut_standard,
    
    -- Écart en pourcentage par rapport à la cible
    CASE 
        WHEN sp.poids_cible IS NOT NULL AND sp.poids_cible > 0 THEN
            ROUND(((dp.poids_moyen - sp.poids_cible) / sp.poids_cible * 100)::NUMERIC, 2)
        ELSE NULL
    END AS ecart_cible_pct
    
FROM donnees_poids dp
JOIN lots l ON dp.lot_id = l.id
LEFT JOIN LATERAL (
    SELECT poids_min, poids_max, poids_cible
    FROM standards_poids 
    WHERE souche_id = l.souche_id 
      AND jour_age = dp.jour_age
      AND date_effet <= dp.date_mesure
    ORDER BY date_effet DESC 
    LIMIT 1
) sp ON true;

COMMENT ON VIEW v_donnees_poids_avec_standards IS 'Données de poids avec comparaison aux standards de la souche';

-- ============================================================================
-- VUE v_donnees_mortalite_avec_standards - Mortalité avec comparaison aux standards
-- ============================================================================
CREATE OR REPLACE VIEW v_donnees_mortalite_avec_standards AS
SELECT 
    dm.id,
    dm.lot_id,
    l.code_lot,
    l.souche_id,
    dm.date_mesure,
    dm.jour_age,
    dm.nombre_morts,
    dm.morts_male,
    dm.morts_femelle,
    dm.effectif_actuel,
    dm.taux_mortalite_cumul,
    dm.source,
    
    -- Standards de la souche
    sm.mortalite_min,
    sm.mortalite_max,
    sm.mortalite_cible,
    
    -- Calcul de l'écart par rapport aux standards
    CASE 
        WHEN sm.mortalite_min IS NULL THEN 'pas_de_standard'
        WHEN dm.taux_mortalite_cumul < sm.mortalite_min THEN 'sous_min'
        WHEN dm.taux_mortalite_cumul > sm.mortalite_max THEN 'sur_max'
        ELSE 'dans_norme'
    END AS statut_standard
    
FROM donnees_mortalite dm
JOIN lots l ON dm.lot_id = l.id
LEFT JOIN LATERAL (
    SELECT mortalite_min, mortalite_max, mortalite_cible
    FROM standards_mortalite 
    WHERE souche_id = l.souche_id 
      AND jour_age = dm.jour_age
      AND date_effet <= dm.date_mesure
    ORDER BY date_effet DESC 
    LIMIT 1
) sm ON true;

COMMENT ON VIEW v_donnees_mortalite_avec_standards IS 'Données de mortalité avec comparaison aux standards de la souche';

-- ============================================================================
-- VUE v_donnees_aliment_avec_standards - Aliment avec comparaison aux standards
-- ============================================================================
CREATE OR REPLACE VIEW v_donnees_aliment_avec_standards AS
SELECT 
    da.id,
    da.lot_id,
    l.code_lot,
    l.souche_id,
    da.date_mesure,
    da.jour_age,
    da.consommation_kg,
    da.conso_par_animal,
    da.indice_conso,
    da.conso_cumul,
    da.source,
    
    -- Standards de la souche
    sa.conso_min,
    sa.conso_max,
    sa.conso_cible,
    
    -- Calcul de l'écart par rapport aux standards
    CASE 
        WHEN sa.conso_min IS NULL THEN 'pas_de_standard'
        WHEN da.conso_par_animal < sa.conso_min THEN 'sous_min'
        WHEN da.conso_par_animal > sa.conso_max THEN 'sur_max'
        ELSE 'dans_norme'
    END AS statut_standard
    
FROM donnees_aliment da
JOIN lots l ON da.lot_id = l.id
LEFT JOIN LATERAL (
    SELECT conso_min, conso_max, conso_cible
    FROM standards_aliment 
    WHERE souche_id = l.souche_id 
      AND jour_age = da.jour_age
      AND date_effet <= da.date_mesure
    ORDER BY date_effet DESC 
    LIMIT 1
) sa ON true;

COMMENT ON VIEW v_donnees_aliment_avec_standards IS 'Données d''aliment avec comparaison aux standards de la souche';

-- ============================================================================
-- VUE v_donnees_oeufs_avec_standards - Œufs avec comparaison aux standards
-- ============================================================================
CREATE OR REPLACE VIEW v_donnees_oeufs_avec_standards AS
SELECT 
    do_data.id,
    do_data.lot_id,
    l.code_lot,
    l.souche_id,
    do_data.date_mesure,
    do_data.jour_age,
    do_data.nombre_oeufs,
    do_data.taux_ponte,
    do_data.source,
    
    -- Standards de la souche
    so.taux_ponte_min,
    so.taux_ponte_max,
    so.taux_ponte_cible,
    
    -- Calcul de l'écart par rapport aux standards
    CASE 
        WHEN so.taux_ponte_min IS NULL THEN 'pas_de_standard'
        WHEN do_data.taux_ponte < so.taux_ponte_min THEN 'sous_min'
        WHEN do_data.taux_ponte > so.taux_ponte_max THEN 'sur_max'
        ELSE 'dans_norme'
    END AS statut_standard
    
FROM donnees_oeufs do_data
JOIN lots l ON do_data.lot_id = l.id
LEFT JOIN LATERAL (
    SELECT taux_ponte_min, taux_ponte_max, taux_ponte_cible
    FROM standards_oeufs 
    WHERE souche_id = l.souche_id 
      AND jour_age = do_data.jour_age
      AND date_effet <= do_data.date_mesure
    ORDER BY date_effet DESC 
    LIMIT 1
) so ON true;

COMMENT ON VIEW v_donnees_oeufs_avec_standards IS 'Données d''œufs avec comparaison aux standards de la souche';

-- ============================================================================
-- VUE v_donnees_graphique - Vue consolidée pour le graphique
-- ============================================================================
CREATE OR REPLACE VIEW v_donnees_graphique AS

-- POIDS
SELECT 
    lot_id, 
    code_lot, 
    date_mesure, 
    jour_age,
    'poids' AS type_donnee,
    poids_moyen AS valeur,
    poids_min AS valeur_min,
    poids_max AS valeur_max,
    poids_cible AS valeur_cible,
    'g' AS unite,
    statut_standard,
    source
FROM v_donnees_poids_avec_standards

UNION ALL

-- MORTALITÉ
SELECT 
    lot_id, 
    code_lot, 
    date_mesure, 
    jour_age,
    'mortalite' AS type_donnee,
    taux_mortalite_cumul AS valeur,
    mortalite_min AS valeur_min,
    mortalite_max AS valeur_max,
    mortalite_cible AS valeur_cible,
    '%' AS unite,
    statut_standard,
    source
FROM v_donnees_mortalite_avec_standards

UNION ALL

-- ŒUFS
SELECT 
    lot_id, 
    code_lot, 
    date_mesure, 
    jour_age,
    'oeufs' AS type_donnee,
    taux_ponte AS valeur,
    taux_ponte_min AS valeur_min,
    taux_ponte_max AS valeur_max,
    taux_ponte_cible AS valeur_cible,
    'œufs/p/j' AS unite,
    statut_standard,
    source
FROM v_donnees_oeufs_avec_standards

UNION ALL

-- ALIMENT
SELECT 
    lot_id, 
    code_lot, 
    date_mesure, 
    jour_age,
    'aliment' AS type_donnee,
    conso_par_animal AS valeur,
    conso_min AS valeur_min,
    conso_max AS valeur_max,
    conso_cible AS valeur_cible,
    'g' AS unite,
    statut_standard,
    source
FROM v_donnees_aliment_avec_standards;

COMMENT ON VIEW v_donnees_graphique IS 'Vue consolidée de toutes les données pour le graphique avec standards';

-- ============================================================================
-- VUE v_resume_lot - Résumé des performances d'un lot
-- ============================================================================
CREATE OR REPLACE VIEW v_resume_lot AS
SELECT 
    l.id AS lot_id,
    l.code_lot,
    l.effectif_depart,
    l.date_mise_place,
    l.statut,
    
    -- Âge actuel
    (CURRENT_DATE - l.date_mise_place) AS age_jours,
    
    -- Dernier poids
    (SELECT poids_moyen FROM donnees_poids WHERE lot_id = l.id ORDER BY date_mesure DESC LIMIT 1) AS dernier_poids,
    (SELECT date_mesure FROM donnees_poids WHERE lot_id = l.id ORDER BY date_mesure DESC LIMIT 1) AS date_dernier_poids,
    
    -- Mortalité cumulée
    (SELECT taux_mortalite_cumul FROM donnees_mortalite WHERE lot_id = l.id ORDER BY date_mesure DESC LIMIT 1) AS mortalite_cumul,
    (SELECT effectif_actuel FROM donnees_mortalite WHERE lot_id = l.id ORDER BY date_mesure DESC LIMIT 1) AS effectif_actuel,
    
    -- Consommation cumulée
    (SELECT conso_cumul FROM donnees_aliment WHERE lot_id = l.id ORDER BY date_mesure DESC LIMIT 1) AS aliment_cumul_kg,
    
    -- Indice de consommation
    (SELECT indice_conso FROM donnees_aliment WHERE lot_id = l.id ORDER BY date_mesure DESC LIMIT 1) AS dernier_ic,
    
    -- Dernière température
    (SELECT temperature FROM donnees_ambiance WHERE lot_id = l.id ORDER BY date_mesure DESC LIMIT 1) AS derniere_temperature,
    
    -- Informations éleveur
    e.code_eleveur,
    CONCAT(e.nom, ' ', COALESCE(e.prenom, '')) AS eleveur_nom,
    
    -- Site et bâtiment
    s.nom AS site_nom,
    b.nom AS batiment_nom
    
FROM lots l
JOIN batiments b ON l.batiment_id = b.id
JOIN sites s ON b.site_id = s.id
JOIN eleveurs e ON s.eleveur_id = e.id
WHERE l.statut = 'actif';

COMMENT ON VIEW v_resume_lot IS 'Résumé des performances actuelles de chaque lot actif';

-- ============================================================================
-- VUE v_alertes_lot - Alertes sur les lots
-- ============================================================================
CREATE OR REPLACE VIEW v_alertes_lot AS
SELECT 
    l.id AS lot_id,
    l.code_lot,
    e.code_eleveur,
    b.nom AS batiment,
    'poids' AS type_alerte,
    dp.date_mesure,
    dp.jour_age,
    dp.poids_moyen AS valeur,
    sp.poids_min AS seuil_min,
    sp.poids_max AS seuil_max,
    CASE 
        WHEN dp.poids_moyen < sp.poids_min THEN 'Poids sous le minimum'
        WHEN dp.poids_moyen > sp.poids_max THEN 'Poids au-dessus du maximum'
    END AS message
FROM donnees_poids dp
JOIN lots l ON dp.lot_id = l.id
JOIN batiments b ON l.batiment_id = b.id
JOIN sites s ON b.site_id = s.id
JOIN eleveurs e ON s.eleveur_id = e.id
LEFT JOIN LATERAL (
    SELECT poids_min, poids_max
    FROM standards_poids 
    WHERE souche_id = l.souche_id 
      AND jour_age = dp.jour_age
      AND date_effet <= dp.date_mesure
    ORDER BY date_effet DESC 
    LIMIT 1
) sp ON true
WHERE l.statut = 'actif'
  AND sp.poids_min IS NOT NULL
  AND (dp.poids_moyen < sp.poids_min OR dp.poids_moyen > sp.poids_max)
  AND dp.date_mesure >= CURRENT_DATE - INTERVAL '7 days'

UNION ALL

-- Alertes mortalité
SELECT 
    l.id AS lot_id,
    l.code_lot,
    e.code_eleveur,
    b.nom AS batiment,
    'mortalite' AS type_alerte,
    dm.date_mesure,
    dm.jour_age,
    dm.taux_mortalite_cumul AS valeur,
    sm.mortalite_min AS seuil_min,
    sm.mortalite_max AS seuil_max,
    'Mortalité au-dessus du seuil' AS message
FROM donnees_mortalite dm
JOIN lots l ON dm.lot_id = l.id
JOIN batiments b ON l.batiment_id = b.id
JOIN sites s ON b.site_id = s.id
JOIN eleveurs e ON s.eleveur_id = e.id
LEFT JOIN LATERAL (
    SELECT mortalite_min, mortalite_max
    FROM standards_mortalite 
    WHERE souche_id = l.souche_id 
      AND jour_age = dm.jour_age
      AND date_effet <= dm.date_mesure
    ORDER BY date_effet DESC 
    LIMIT 1
) sm ON true
WHERE l.statut = 'actif'
  AND sm.mortalite_max IS NOT NULL
  AND dm.taux_mortalite_cumul > sm.mortalite_max
  AND dm.date_mesure >= CURRENT_DATE - INTERVAL '7 days'

ORDER BY date_mesure DESC;

COMMENT ON VIEW v_alertes_lot IS 'Alertes sur les lots actifs (écarts par rapport aux standards)';
