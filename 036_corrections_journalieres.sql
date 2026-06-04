-- ============================================================
-- 036_corrections_journalieres.sql
-- Table d'audit des corrections manuelles sur données journalières
-- Les corrections priment sur les données Tuffigo à l'affichage
-- n8n continue ses Upsert normalement — aucun changement côté sync
-- ============================================================

CREATE TABLE IF NOT EXISTS corrections_journalieres (
    id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lot_id           UUID NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
    jour_age         INTEGER NOT NULL,
    champ            VARCHAR(100) NOT NULL,
    valeur_originale TEXT,
    valeur_corrigee  TEXT NOT NULL,
    modifie_par      UUID,
    modifie_par_nom  TEXT,
    modifie_par_role TEXT,
    created_at       TIMESTAMPTZ DEFAULT now(),
    actif            BOOLEAN DEFAULT true
);

COMMENT ON TABLE corrections_journalieres IS
    'Corrections manuelles des données journalières — priment sur les données Tuffigo à l''affichage';
COMMENT ON COLUMN corrections_journalieres.champ IS
    'Clé du champ corrigé : poids_moyen | gmq | homogeneite | nombre_morts | aliment_animal | eau_litres | eau_animal | eau_ratio';
COMMENT ON COLUMN corrections_journalieres.valeur_originale IS
    'Valeur Tuffigo au moment de la correction (pour restauration)';
COMMENT ON COLUMN corrections_journalieres.actif IS
    'true = correction actuellement active ; false = remplacée par une nouvelle correction ou restaurée';

-- Index pour les requêtes fréquentes (lecture par lot + jour + champ)
CREATE INDEX IF NOT EXISTS idx_corrections_lot   ON corrections_journalieres(lot_id);
CREATE INDEX IF NOT EXISTS idx_corrections_champ ON corrections_journalieres(lot_id, jour_age, champ);
CREATE INDEX IF NOT EXISTS idx_corrections_date  ON corrections_journalieres(created_at DESC);

-- ── RLS ──────────────────────────────────────────────────────
ALTER TABLE corrections_journalieres ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "corrections_select" ON corrections_journalieres;
CREATE POLICY "corrections_select" ON corrections_journalieres
    FOR SELECT USING (true);

-- ── RPC : enregistrer une correction ─────────────────────────
-- Désactive la correction active précédente puis insère la nouvelle
DROP FUNCTION IF EXISTS save_correction_journaliere(uuid, integer, text, text, text, uuid, text, text);
CREATE OR REPLACE FUNCTION save_correction_journaliere(
    p_lot_id           UUID,
    p_jour_age         INTEGER,
    p_champ            TEXT,
    p_valeur_originale TEXT,
    p_valeur_corrigee  TEXT,
    p_modifie_par      UUID,
    p_modifie_par_nom  TEXT,
    p_modifie_par_role TEXT
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    -- Désactiver l'éventuelle correction active pour ce champ/jour
    UPDATE corrections_journalieres
    SET actif = false
    WHERE lot_id   = p_lot_id
      AND jour_age  = p_jour_age
      AND champ     = p_champ
      AND actif     = true;

    -- Insérer la nouvelle correction (conserve l'historique complet)
    INSERT INTO corrections_journalieres (
        lot_id, jour_age, champ,
        valeur_originale, valeur_corrigee,
        modifie_par, modifie_par_nom, modifie_par_role
    ) VALUES (
        p_lot_id, p_jour_age, p_champ,
        p_valeur_originale, p_valeur_corrigee,
        p_modifie_par, p_modifie_par_nom, p_modifie_par_role
    );
END;
$$;

-- ── RPC : restaurer la valeur d'origine ──────────────────────
-- Désactive la correction active + insère une entrée de restauration dans le journal
DROP FUNCTION IF EXISTS restore_correction_journaliere(uuid, integer, text, text, uuid, text, text);
CREATE OR REPLACE FUNCTION restore_correction_journaliere(
    p_lot_id           UUID,
    p_jour_age         INTEGER,
    p_champ            TEXT,
    p_valeur_originale TEXT,   -- valeur d'origine à laquelle on revient
    p_modifie_par      UUID,
    p_modifie_par_nom  TEXT,
    p_modifie_par_role TEXT
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    -- Marquer la correction active comme désactivée
    UPDATE corrections_journalieres
    SET actif = false
    WHERE lot_id   = p_lot_id
      AND jour_age  = p_jour_age
      AND champ     = p_champ
      AND actif     = true;

    -- Insérer une entrée de restauration dans le journal pour traçabilité
    -- actif=false car la valeur affichée revient à la source Tuffigo
    INSERT INTO corrections_journalieres (
        lot_id, jour_age, champ,
        valeur_originale, valeur_corrigee,
        modifie_par, modifie_par_nom, modifie_par_role,
        actif
    ) VALUES (
        p_lot_id, p_jour_age, p_champ,
        '(restauration)', p_valeur_originale,
        p_modifie_par, p_modifie_par_nom, p_modifie_par_role,
        false
    );
END;
$$;
