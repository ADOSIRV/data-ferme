/**
 * pdf-service.js — Micro-service de génération PDF headless pour Dataferme
 *
 * Génère des PDFs IDENTIQUES au bouton "Rapport" de l'application, en utilisant
 * le même code (rapport-pdf.html + jsPDF) via Puppeteer.
 *
 * Déploiement recommandé : conteneur Docker via Coolify (voir Dockerfile).
 * Déploiement alternatif  : PM2 sur le serveur n8n.
 *
 * Usage :
 *   POST http://localhost:3001/generate-pdf
 *   Content-Type: application/json
 *   Body: { "injectData": { ... } }
 *         // reportUrl est optionnel : par défaut rapport-pdf.html est servi localement
 *
 *   Réponse : { "success": true, "base64": "...", "filename": "Rapport_lot_XXX_2026-06-11.pdf" }
 */

'use strict';

const express    = require('express');
const puppeteer  = require('puppeteer');
const path       = require('path');
const app        = express();

app.use(express.json({ limit: '20mb' }));

// ── Port (déclaré tôt car utilisé dans la route /generate-pdf) ───────────────
const PORT = process.env.PDF_SERVICE_PORT || 3001;

// ── Servir rapport-pdf.html en local ─────────────────────────────────────────
// Puppeteer charge la page depuis localhost → pas de dépendance externe,
// plus fiable que charger depuis https://dataferme.com/rapport-pdf.html
app.use(express.static(path.join(__dirname)));

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', function(req, res) {
    res.json({ status: 'ok', service: 'dataferme-pdf', time: new Date().toISOString() });
});

// ── Génération PDF ─────────────────────────────────────────────────────────────
app.post('/generate-pdf', async function(req, res) {
    const { injectData, reportUrl } = req.body;

    if (!injectData) {
        return res.status(400).json({ success: false, error: 'injectData manquant dans le corps de la requete' });
    }

    // URL locale par défaut → rapport-pdf.html servi par ce même serveur Express
    // Avantage : fonctionne sans déployer rapport-pdf.html sur dataferme.com
    const url = reportUrl || ('http://localhost:' + PORT + '/rapport-pdf.html');
    console.log('[pdf-service] Generation PDF pour lot:', (injectData.lot && injectData.lot.code_lot) || 'inconnu');

    let browser;
    try {
        browser = await puppeteer.launch({
            headless: 'new',
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-gpu'
            ]
        });

        const page = await browser.newPage();

        // Timeout page navigation : 30 secondes
        await page.goto(url, { waitUntil: 'networkidle0', timeout: 30000 });

        // Injecter les données du lot dans la page
        await page.evaluate(function(data) {
            window.INJECT_DATA = data;
            window.DATA_READY  = true;
        }, injectData);

        // Attendre que la génération PDF soit terminée (max 90 secondes)
        await page.waitForFunction(
            function() { return window.RAPPORT_DONE === true; },
            { timeout: 90000, polling: 500 }
        );

        // Récupérer le résultat
        const result = await page.evaluate(function() {
            return {
                base64:   window.RAPPORT_BASE64   || null,
                filename: window.RAPPORT_FILENAME || 'rapport.pdf',
                error:    window.RAPPORT_ERROR    || null
            };
        });

        await page.close();

        if (result.error) {
            console.error('[pdf-service] Erreur interne page:', result.error);
            return res.status(500).json({ success: false, error: result.error });
        }
        if (!result.base64) {
            return res.status(500).json({ success: false, error: 'Aucune donnee PDF generee' });
        }

        console.log('[pdf-service] PDF genere avec succes:', result.filename, '(' + Math.round(result.base64.length * 0.75 / 1024) + ' KB)');
        res.json({ success: true, base64: result.base64, filename: result.filename });

    } catch (err) {
        console.error('[pdf-service] Erreur Puppeteer:', err.message);
        res.status(500).json({ success: false, error: err.message });
    } finally {
        if (browser) {
            try { await browser.close(); } catch(e) {}
        }
    }
});

// ── Démarrage ──────────────────────────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', function() {
    console.log('[pdf-service] Service démarré sur http://0.0.0.0:' + PORT);
    console.log('[pdf-service] rapport-pdf.html servi depuis :', path.join(__dirname, 'rapport-pdf.html'));
    console.log('[pdf-service] Endpoint : POST http://0.0.0.0:' + PORT + '/generate-pdf');
});
