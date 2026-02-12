# Workflows N8N - Synchronisation Tuffigo Rapidex

## 📁 Fichiers

```
n8n/
├── workflow_tuffigo_sync_main.json     # Workflow principal (données production)
├── workflow_tuffigo_sync_souches.json  # Workflow souches et standards
└── README.md                           # Ce fichier
```

## 🚀 Installation

### 1. Prérequis

- N8N installé et fonctionnel
- Supabase configuré avec les tables créées
- Clé API Tuffigo Rapidex (demander à votre contact commercial)

### 2. Configurer les Variables N8N

Dans N8N, allez dans **Settings** → **Variables** et créez :

| Variable | Description | Exemple |
|----------|-------------|---------|
| `SUPABASE_URL` | URL de votre projet Supabase | `https://xxxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Clé anonyme Supabase | `eyJhbGciOiJIUzI1...` |
| `SUPABASE_SERVICE_KEY` | Clé service (admin) Supabase | `eyJhbGciOiJIUzI1...` |
| `TUFFIGO_API_KEY` | Clé API Tuffigo (optionnel si stockée en BDD) | `votre-cle-api` |

### 3. Configurer la clé API dans Supabase

Insérez votre clé API Tuffigo dans la table `api_config` :

```sql
INSERT INTO api_config (api_key, base_url, is_active)
VALUES ('VOTRE_CLE_API_TUFFIGO', 'https://api.mytuffigorapidex.com', true);
```

### 4. Exécuter le script SQL des fonctions RPC

Avant d'importer les workflows, exécutez le script `007_create_rpc_functions.sql` dans Supabase.

### 5. Importer les workflows dans N8N

1. Ouvrez N8N
2. Cliquez sur **"..."** → **Import from File**
3. Sélectionnez `workflow_tuffigo_sync_main.json`
4. Répétez pour `workflow_tuffigo_sync_souches.json`

---

## 📋 Workflows

### Workflow 1 : Synchronisation Principale

**Fichier** : `workflow_tuffigo_sync_main.json`

**Fréquence** : Toutes les heures

**Flux de données** :

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Éleveurs   │ →  │   Sites     │ →  │  Bâtiments  │ →  │    Lots     │
│ (breeders)  │    │ (breedings) │    │ (buildings) │    │  (batchs)   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                │
                                                                ▼
                                            ┌─────────────────────────────┐
                                            │   Données de Production     │
                                            ├─────────────────────────────┤
                                            │ • Poids (animals_weight)    │
                                            │ • Mortalité (animals_mort.) │
                                            │ • Aliment (consumption)     │
                                            │ • Eau (consumption)         │
                                            │ • Ambiance (ambiance)       │
                                            │ • Énergie (energy)          │
                                            └─────────────────────────────┘
```

**Endpoints API utilisés** :
- `GET /group/breeders` - Liste des éleveurs
- `GET /group/breeders/{id}/breedings` - Sites d'un éleveur
- `GET /group/breedings/{id}/buildings` - Bâtiments d'un site
- `GET /group/buildings/{id}/batchs?filter=current` - Lots actifs
- `GET /group/buildings/{building_id}/batch/{batch_id}` - Données de production

---

### Workflow 2 : Synchronisation Souches

**Fichier** : `workflow_tuffigo_sync_souches.json`

**Fréquence** : 1 fois par jour à 6h

**Flux de données** :

```
┌─────────────┐    ┌─────────────────────────────────────┐
│  Souches    │ →  │  Standards par jour d'âge           │
│  (strains)  │    ├─────────────────────────────────────┤
└─────────────┘    │ • Standards Poids (weight)          │
                   │ • Standards Mortalité (cumMortality)│
                   │ • Standards Aliment (feedConsumption│
                   └─────────────────────────────────────┘
```

**Endpoints API utilisés** :
- `GET /group/strains` - Liste des souches
- `GET /group/strains/{id}` - Détail d'une souche avec consignes

---

## ⚙️ Configuration des Nodes

### Authentification API Tuffigo

Tous les appels à l'API Tuffigo utilisent un header `Authorization: Bearer {API_KEY}`.

La clé API est récupérée depuis :
1. La table `api_config` de Supabase (recommandé)
2. Ou la variable N8N `TUFFIGO_API_KEY` (alternative)

### Gestion des erreurs

Les workflows incluent :
- Vérification de la configuration API avant exécution
- Logs de synchronisation dans la table `sync_logs`
- Gestion des cas où les entités parentes n'existent pas

---

## 🔧 Personnalisation

### Modifier la fréquence de synchronisation

Dans le node "Toutes les heures" ou "Tous les jours 6h" :
- Cliquez sur le node
- Modifiez l'intervalle selon vos besoins

### Ajouter des notifications

Vous pouvez ajouter des nodes après "Log Succès" pour :
- Envoyer un email de résumé
- Notifier sur Slack/Discord
- Créer une alerte si erreur

### Filtrer les éleveurs

Modifiez le node "GET Éleveurs Tuffigo" pour ajouter des filtres :
```
https://api.mytuffigorapidex.com/group/breeders?filter=active
```

---

## 📊 Tables Supabase utilisées

| Table | Action | Description |
|-------|--------|-------------|
| `api_config` | READ | Configuration API |
| `eleveurs` | UPSERT | Données éleveurs |
| `sites` | UPSERT | Sites d'exploitation |
| `batiments` | UPSERT | Bâtiments |
| `lots` | UPSERT | Lots de volailles |
| `souches` | UPSERT | Souches |
| `standards_poids` | UPSERT | Standards poids |
| `standards_mortalite` | UPSERT | Standards mortalité |
| `standards_aliment` | UPSERT | Standards aliment |
| `donnees_poids` | UPSERT | Mesures poids |
| `donnees_mortalite` | UPSERT | Mesures mortalité |
| `donnees_aliment` | UPSERT | Consommation aliment |
| `donnees_eau` | UPSERT | Consommation eau |
| `donnees_ambiance` | UPSERT | Température, hygrométrie |
| `donnees_energie` | UPSERT | Gaz, électricité |
| `sync_logs` | INSERT | Journal de synchronisation |

---

## 🔍 Dépannage

### Erreur "Configuration API manquante"

1. Vérifiez que la table `api_config` contient une entrée active
2. Vérifiez que `is_active = true`

### Erreur "Éleveur/Site/Bâtiment non trouvé"

Les entités doivent être synchronisées dans l'ordre :
1. Éleveurs
2. Sites
3. Bâtiments
4. Lots

Si une entité parente manque, la synchronisation de l'entité enfant échoue.

### Erreur 401 Unauthorized

- Vérifiez votre clé API Tuffigo
- Contactez Tuffigo pour vérifier que votre compte est actif

### Erreur 403 Forbidden

- Vérifiez les permissions de votre compte Tuffigo
- Certains endpoints peuvent être restreints selon votre abonnement

### Pas de données dans Supabase

1. Vérifiez les logs d'exécution N8N
2. Consultez la table `sync_logs` pour les erreurs
3. Vérifiez que les fonctions RPC sont créées (`007_create_rpc_functions.sql`)

---

## 📈 Monitoring

### Vérifier les synchronisations

```sql
-- Dernières synchronisations
SELECT * FROM sync_logs 
ORDER BY synced_at DESC 
LIMIT 20;

-- Synchronisations en erreur
SELECT * FROM sync_logs 
WHERE status = 'error' 
ORDER BY synced_at DESC;
```

### Vérifier les données synchronisées

```sql
-- Éleveurs synchronisés depuis Tuffigo
SELECT code_eleveur, nom, tuffigo_id, last_sync_at 
FROM eleveurs 
WHERE tuffigo_id IS NOT NULL 
ORDER BY last_sync_at DESC;

-- Lots avec données récentes
SELECT l.code_lot, COUNT(dp.id) as nb_mesures_poids
FROM lots l
LEFT JOIN donnees_poids dp ON l.id = dp.lot_id
WHERE l.statut = 'actif'
GROUP BY l.code_lot;
```

---

## 🔗 Liens utiles

- [Documentation API Tuffigo](https://api.mytuffigorapidex.com/group/docs/)
- [Documentation N8N](https://docs.n8n.io/)
- [Documentation Supabase](https://supabase.com/docs)

---

## 📝 Changelog

### v1.0.0 (2024-01-29)
- Version initiale
- Synchronisation éleveurs, sites, bâtiments, lots
- Synchronisation données de production (6 types)
- Synchronisation souches et standards
