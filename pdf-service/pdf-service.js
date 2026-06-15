/**
 * pdf-service.js — Micro-service de génération PDF headless pour Dataferme
 *
 * Génère des PDFs IDENTIQUES au bouton "Rapport" de l'application, en utilisant
 * le même code (rapport-pdf.html + jsPDF) via Puppeteer.
 *
 * Déploiement recommandé : conteneur Docker via Coolify (voir Dockerfile).
 *
 * Endpoints :
 *   POST /generate-pdf
 *     Body : { "injectData": { ... } }
 *     Réponse : { "success": true, "base64": "...", "filename": "..." }
 *
 *   POST /generate-pdf-and-upload          ← SCALABLE : zéro binaire dans n8n
 *     Body : { "injectData": { ... }, "supabase_url": "...", "supabase_key": "...", "storage_path": "eleveur_id/codeSafe.pdf" }
 *     Réponse : { "success": true, "storageUrl": "https://...", "filename": "..." }
 */

'use strict';

const express    = require('express');
const puppeteer  = require('puppeteer');
const path       = require('path');
const http       = require('http');
const https      = require('https');
const urlModule  = require('url');
const app        = express();

app.use(express.json({ limit: '20mb' }));

const PORT = process.env.PDF_SERVICE_PORT || 3001;

app.use(express.static(path.join(__dirname)));

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', function(req, res) {
    res.json({ status: 'ok', service: 'dataferme-pdf', time: new Date().toISOString() });
});

// ── Fonction partagée : génération PDF via Puppeteer ─────────────────────────
async function genererPdf(injectData, reportUrl) {
    const url = reportUrl || ('http://localhost:' + PORT + '/rapport-pdf.html');
    console.log('[pdf-service] Génération pour lot:', (injectData.lot && injectData.lot.code_lot) || 'inconnu');

    const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu']
    });

    try {
        const page = await browser.newPage();
        await page.goto(url, { waitUntil: 'networkidle0', timeout: 30000 });

        await page.evaluate(function(data) {
            window.INJECT_DATA = data;
            window.DATA_READY  = true;
        }, injectData);

        await page.waitForFunction(
            function() { return window.RAPPORT_DONE === true; },
            { timeout: 90000, polling: 500 }
        );

        const result = await page.evaluate(function() {
            return {
                base64:   window.RAPPORT_BASE64   || null,
                filename: window.RAPPORT_FILENAME || 'rapport.pdf',
                error:    window.RAPPORT_ERROR    || null
            };
        });

        await page.close();

        if (result.error) throw new Error(result.error);
        if (!result.base64) throw new Error('Aucune donnée PDF générée');

        console.log('[pdf-service] PDF OK :', result.filename, '(' + Math.round(result.base64.length * 0.75 / 1024) + ' KB)');
        return result;

    } finally {
        try { await browser.close(); } catch(e) {}
    }
}

// ── Fonction partagée : upload binaire vers Supabase Storage ─────────────────
function uploadSupabase(supabase_url, supabase_key, storage_path, pdfBuffer) {
    const uploadUrl  = supabase_url + '/storage/v1/object/rapports-lot/' + storage_path;
    const parsedUrl  = urlModule.parse(uploadUrl);
    const transport  = parsedUrl.protocol === 'https:' ? https : http;

    console.log('[pdf-service] Upload Supabase :', uploadUrl);

    return new Promise(function(resolve, reject) {
        const options = {
            hostname: parsedUrl.hostname,
            port:     parsedUrl.port || (parsedUrl.protocol === 'https:' ? 443 : 80),
            path:     parsedUrl.path,
            method:   'POST',
            headers: {
                'apikey':         supabase_key,
                'Authorization':  'Bearer ' + supabase_key,
                'Content-Type':   'application/pdf',
                'Content-Length': pdfBuffer.length,
                'x-upsert':       'true'
            }
        };

        const req = transport.request(options, function(resp) {
            let body = '';
            resp.on('data', function(chunk) { body += chunk; });
            resp.on('end', function() {
                if (resp.statusCode >= 200 && resp.statusCode < 300) {
                    console.log('[pdf-service] Upload OK (' + resp.statusCode + ')');
                    resolve();
                } else {
                    reject(new Error('Supabase Storage erreur ' + resp.statusCode + ' : ' + body));
                }
            });
        });

        req.on('error', reject);
        req.write(pdfBuffer);
        req.end();
    });
}

// ── POST /generate-pdf ────────────────────────────────────────────────────────
// Usage actuel (n8n retourne base64, convertit en binaire, uploade séparément)
app.post('/generate-pdf', async function(req, res) {
    const { injectData, reportUrl } = req.body;
    if (!injectData) {
        return res.status(400).json({ success: false, error: 'injectData manquant' });
    }
    try {
        const result = await genererPdf(injectData, reportUrl);
        res.json({ success: true, base64: result.base64, filename: result.filename });
    } catch (err) {
        console.error('[pdf-service] /generate-pdf erreur :', err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// ── POST /generate-pdf-and-upload ─────────────────────────────────────────────
// Usage scalable : le service uploade directement sur Supabase, renvoie l'URL.
// Aucun binaire ne transite par n8n → scalable à l'infini.
app.post('/generate-pdf-and-upload', async function(req, res) {
    const { injectData, reportUrl, supabase_url, supabase_key, storage_path } = req.body;

    if (!injectData) {
        return res.status(400).json({ success: false, error: 'injectData manquant' });
    }
    if (!supabase_url || !supabase_key || !storage_path) {
        return res.status(400).json({ success: false, error: 'supabase_url, supabase_key et storage_path sont requis' });
    }

    try {
        // 1. Générer le PDF
        const result    = await genererPdf(injectData, reportUrl);
        const pdfBuffer = Buffer.from(result.base64, 'base64');

        // 2. Uploader directement sur Supabase Storage
        await uploadSupabase(supabase_url, supabase_key, storage_path, pdfBuffer);

        // 3. Construire et retourner l'URL publique
        const storageUrl = supabase_url + '/storage/v1/object/public/rapports-lot/' + storage_path;
        console.log('[pdf-service] ✓ URL publique :', storageUrl);

        res.json({ success: true, storageUrl: storageUrl, filename: result.filename });

    } catch (err) {
        console.error('[pdf-service] /generate-pdf-and-upload erreur :', err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// ── Démarrage ──────────────────────────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', function() {
    console.log('[pdf-service] Service démarré sur http://0.0.0.0:' + PORT);
    console.log('[pdf-service] rapport-pdf.html servi depuis :', path.join(__dirname, 'rapport-pdf.html'));
    console.log('[pdf-service] Endpoints :');
    console.log('  POST /generate-pdf             (retourne base64)');
    console.log('  POST /generate-pdf-and-upload  (upload Supabase → retourne URL)');
});
