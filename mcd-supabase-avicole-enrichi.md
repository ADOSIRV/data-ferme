# Modèle Conceptuel de Données - Suivi Production Avicole
## Enrichi avec l'API Tuffigo Rapidex
### Version 2.1 — Mise à jour migrations 008 → 012

---

## 📊 Synthèse des Entités de l'API Tuffigo Rapidex

D'après la documentation officielle (`https://api.mytuffigorapidex.com/group/docs/`), voici la hiérarchie des données :

```
GROUPEMENT (votre compte API)
    └── ÉLEVEURS (breeder_id)
            └── ÉLEVAGES (breeding_id) = Sites
                    └── BÂTIMENTS (building_id)
                            └── LOTS (batch) = Bandes
                                    └── DONNÉES DE PRODUCTION (data)
                                            ├── consumption (consommation)
                                            ├── ambiance (température, hygrométrie)
                                            ├── energy (gaz, électricité)
                                            ├── animals_mortality (mortalité)
                                            └── animals_weight (poids)
            └── RÉGULATEURS (regulators)
            └── PRÉ-BANDES (presetbatchs)
    └── SOUCHES (strains)
```

**Authentification API :** token statique dans le header `Authorization: token <api_key>`
**URL de base :** `https://api.mytuffigorapidex.com/group/v2/`

---

## 🗂️ Schéma Relationnel Complet

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           MODÈLE DE DONNÉES ENRICHI TUFFIGO v2.1                        │
└─────────────────────────────────────────────────────────────────────────────────────────┘

                                    AUTHENTIFICATION / CONFIGURATION
┌──────────────────────┐
│     API_CONFIG       │  Configuration de connexion à l'API Tuffigo
├──────────────────────┤
│ PK id                │
│    api_key           │◄── Token API (Authorization: token <api_key>)
│    api_login         │◄── Login portail web Tuffigo (NOUVEAU 012)
│    api_password      │◄── Mot de passe portail web (NOUVEAU 012)
│    base_url          │◄── https://api.mytuffigorapidex.com/group/v2/ (CORRIGÉ 012)
│    last_sync         │
│    is_active         │
│    created_at        │
│    updated_at        │
└──────────────────────┘

                                    UTILISATEURS
┌──────────────────┐       ┌────────────────────────┐
│     USERS        │       │       ELEVEURS          │
├──────────────────┤       ├────────────────────────┤
│ PK id            │       │ PK id                  │
│    email         │       │    tuffigo_id          │◄── breeder_id API
│    password_hash │◄──────│ FK user_id             │
│    nom           │  0,1  │    inrae_id            │◄── Identifiant national (SIRET)
│    role          │       │    code_eleveur        │
│    is_active     │       │    nom                 │
│    created_at    │       │    prenom              │
│    last_login    │       │    raison_sociale      │
└──────────────────┘       │    telephone           │
                           │    email               │
                           │    siret               │◄── siret API
                           │    adresse_json        │◄── address API (JSONB)
                           │    permissions_json    │◄── generalPermissions API
                           │    statut_tuffigo      │
                           │    nom_fournisseur     │◄── (LEGACY 008 - remplacé par
                           │    email_fournisseur   │     fournisseurs_eleveur)
                           │    created_at          │
                           └────────────────────────┘
                                    │
                                    │ 1,n
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                                      SITES / ÉLEVAGES                                    │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌──────────────────┐                                                                    │
│  │      SITES       │  = "Élevages" dans l'API Tuffigo (breeding)                        │
│  ├──────────────────┤                                                                    │
│  │ PK id            │                                                                    │
│  │    tuffigo_id    │◄── breeding_id API                                                 │
│  │ FK eleveur_id    │                                                                    │
│  │    nom           │◄── name API                                                        │
│  │    adresse       │◄── address.street API                                              │
│  │    code_postal   │◄── address.zipCode API                                             │
│  │    ville         │◄── address.city API                                                │
│  │    departement   │                                                                    │
│  │    created_at    │                                                                    │
│  └──────────────────┘                                                                    │
│           │                                                                              │
│           │ 1,n                                                                          │
│           ▼                                                                              │
│  ┌──────────────────┐       ┌──────────────────┐                                         │
│  │    BATIMENTS     │       │   REGULATEURS    │  Régulateurs Tuffigo connectés          │
│  ├──────────────────┤       ├──────────────────┤                                         │
│  │ PK id            │       │ PK id            │                                         │
│  │    tuffigo_id    │◄──────│    tuffigo_id    │◄── id API                               │
│  │ FK site_id       │  1,n  │ FK batiment_id   │                                         │
│  │    nom           │       │    nom           │◄── name API                             │
│  │    capacite      │       │    type          │◄── type (avitouch, etc.)                │
│  │    created_at    │       │    version       │◄── version API                          │
│  └──────────────────┘       │    created_at_tf │◄── createdAtDate API                    │
│                             │    created_at    │                                         │
│                             └──────────────────┘                                         │
└──────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              SOUCHES ET STANDARDS                                        │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌──────────────────┐                                                                    │
│  │     SOUCHES      │  Gérées via l'API Tuffigo (strains)                                │
│  ├──────────────────┤                                                                    │
│  │ PK id            │                                                                    │
│  │    tuffigo_id    │◄── id API                                                          │
│  │    nom           │◄── name API                                                        │
│  │    type          │◄── shared (true=partagée, false=privée)                            │
│  │    description   │                                                                    │
│  │    consignes_json│◄── data.daily API (JSONB)                                          │
│  │    created_at_tf │◄── date API                                                        │
│  │    created_at    │                                                                    │
│  └──────────────────┘                                                                    │
│           │                                                                              │
│           │ 1,n (standards par jour d'âge)                                               │
│           ▼                                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                      │
│  │ STANDARDS   │  │ STANDARDS   │  │ STANDARDS   │  │ STANDARDS   │                      │
│  │ _POIDS      │  │ _MORTALITE  │  │ _OEUFS      │  │ _ALIMENT    │                      │
│  ├─────────────┤  ├─────────────┤  ├─────────────┤  ├─────────────┤                      │
│  │PK id        │  │PK id        │  │PK id        │  │PK id        │                      │
│  │FK souche_id │  │FK souche_id │  │FK souche_id │  │FK souche_id │                      │
│  │   jour_age  │  │   jour_age  │  │   jour_age  │  │   jour_age  │                      │
│  │   poids_min │  │   morta_min │  │   taux_min  │  │   conso_min │                      │
│  │   poids_max │  │   morta_max │  │   taux_max  │  │   conso_max │                      │
│  │   date_effet│  │   date_effet│  │   date_effet│  │   date_effet│                      │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘                      │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                                    LOTS / BANDES                                         │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌──────────────────────────┐                                                            │
│  │          LOTS            │  = "Bandes" dans l'API Tuffigo (batch)                     │
│  ├──────────────────────────┤                                                            │
│  │ PK id                    │                                                            │
│  │    tuffigo_id            │◄── id API                                                  │
│  │ FK batiment_id           │◄── building_id API                                         │
│  │ FK souche_id             │◄── strain.id API                                           │
│  │    code_lot              │◄── name API                                                │
│  │    effectif_depart       │◄── animals.delivered (somme male+female)                   │
│  │    effectif_male         │◄── animals[kind=male].delivered                            │
│  │    effectif_femelle      │◄── animals[kind=female].delivered                          │
│  │    date_mise_place       │◄── entranceDate API                                        │
│  │    date_sortie_prevue    │◄── exitDate API                                            │
│  │    statut                │◄── En cours si pas de exitDate passée                      │
│  │    couvoir_id            │◄── hatchery_id API                                         │
│  │    created_at            │                                                            │
│  └──────────────────────────┘                                                            │
│                                                                                          │
│  ┌──────────────────────────┐                                                            │
│  │      PRE_BANDES          │  Pré-bandes pour préparer les lots (presetbatchs)          │
│  ├──────────────────────────┤                                                            │
│  │ PK id                    │                                                            │
│  │    tuffigo_id            │◄── id API                                                  │
│  │ FK eleveur_id            │◄── breeder_id API                                          │
│  │ FK batiment_id           │◄── building_id API                                         │
│  │ FK souche_id             │◄── inrae_id API (lien vers souche)                         │
│  │    nom                   │◄── name API                                                │
│  │    effectif_male         │◄── animals[kind=male].delivered                            │
│  │    effectif_femelle      │◄── animals[kind=female].delivered                          │
│  │    date_entree_prevue    │◄── entranceDate API                                        │
│  │    date_sortie_prevue    │◄── exitDate API                                            │
│  │    created_at            │                                                            │
│  └──────────────────────────┘                                                            │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                    COMMANDES D'ALIMENT (NOUVEAU — migrations 008-011)                    │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌──────────────────────────┐       ┌──────────────────────────┐                         │
│  │     TYPES_ALIMENT        │       │   FOURNISSEURS_ELEVEUR   │                         │
│  ├──────────────────────────┤       ├──────────────────────────┤                         │
│  │ PK id                    │       │ PK id                    │                         │
│  │    code_aliment          │◄─UNIQ │ FK eleveur_id            │◄── 1 éleveur → n four.  │
│  │    nom                   │  (011)│    nom                   │                         │
│  │    categorie             │  (011)│    rue                   │◄── (010, remplace adresse)│
│  │    unite                 │  (011)│    code_postal           │  (010)                   │
│  │    description           │       │    ville                 │  (010)                   │
│  │    is_active             │       │    contact_nom           │                         │
│  │    created_at            │       │    email                 │                         │
│  └──────────────────────────┘       │    is_active             │                         │
│             │ 0,n                   │    created_at            │                         │
│             │                       │    updated_at            │                         │
│             │                       └──────────────────────────┘                         │
│             │                                    │ 0,n                                   │
│             ▼                                    │                                       │
│  ┌──────────────────────────────────────────────────────────────────────────────────────┐│
│  │                         COMMANDES_ALIMENT                                            ││
│  ├──────────────────────────────────────────────────────────────────────────────────────┤│
│  │ PK id                                                                                ││
│  │ FK eleveur_id                           NOT NULL → eleveurs.id                       ││
│  │ FK type_aliment_id                      NULLABLE → types_aliment.id                  ││
│  │ FK fournisseur_eleveur_id               NULLABLE → fournisseurs_eleveur.id (009)     ││
│  │    quantite                             DECIMAL NOT NULL CHECK (> 0)                 ││
│  │    unite                                TEXT DEFAULT 'tonnes'                        ││
│  │    date_livraison_souhaitee             DATE NOT NULL                                ││
│  │    date_livraison_confirmee             DATE                                         ││
│  │    heure_livraison_confirmee            TEXT                                         ││
│  │    statut                               TEXT CHECK IN ('en_attente','confirmee',      ││
│  │                                                        'livree','annulee')            ││
│  │    notes                                TEXT                                         ││
│  │    confirmation_token                   UUID UNIQUE (lien vers confirm.html)         ││
│  │    confirmation_token_expire_at         TIMESTAMPTZ DEFAULT +30 jours               ││
│  │    email_envoye_at                      TIMESTAMPTZ                                  ││
│  │    created_at                           TIMESTAMPTZ                                  ││
│  │    updated_at                           TIMESTAMPTZ                                  ││
│  └──────────────────────────────────────────────────────────────────────────────────────┘│
│                                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────────┐│
│  │              VUE : v_planning_commandes (008/009)                                    ││
│  ├──────────────────────────────────────────────────────────────────────────────────────┤│
│  │  JOIN commandes_aliment + eleveurs + types_aliment + fournisseurs_eleveur            ││
│  │  Expose : id, eleveur_id, eleveur_nom, eleveur_prenom, code_eleveur,                 ││
│  │           email_fournisseur (COALESCE fournisseurs_eleveur / eleveurs),              ││
│  │           nom_fournisseur (idem COALESCE),                                           ││
│  │           fournisseur_contact, fournisseur_adresse,                                  ││
│  │           fournisseur_eleveur_id, type_aliment,                                      ││
│  │           quantite, unite, dates livraison, statut, token, etc.                      ││
│  └──────────────────────────────────────────────────────────────────────────────────────┘│
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                          DONNÉES DE PRODUCTION (depuis l'API)                            │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌──────────────────────────┐  ┌──────────────────────────┐                              │
│  │    DONNEES_POIDS         │  │   DONNEES_MORTALITE      │                              │
│  ├──────────────────────────┤  ├──────────────────────────┤                              │
│  │ PK id                    │  │ PK id                    │                              │
│  │ FK lot_id                │  │ FK lot_id                │                              │
│  │    date_mesure           │  │    date_mesure           │                              │
│  │    jour_age              │  │    jour_age              │                              │
│  │    poids_moyen           │  │    nombre_morts          │◄── totalDeadAnimals         │
│  │    poids_moyen_male      │  │    morts_male            │◄── animals[male].dead       │
│  │    poids_moyen_femelle   │  │    morts_femelle         │◄── animals[female].dead     │
│  │    nb_pesees             │  │    morts_elimines        │◄── animals[].eliminated     │
│  │    homogeneite           │  │    morts_malades         │◄── animals[].cardiacDeath   │
│  │    objectif_poids        │  │    effectif_actuel       │                              │
│  │    nb_pesees_total       │  │    taux_mortalite_cumul  │                              │
│  │    source                │  │    source                │◄── 'tuffigo' ou 'manuel'    │
│  │    created_at            │  │    created_at            │                              │
│  └──────────────────────────┘  └──────────────────────────┘                              │
│                                                                                          │
│  ┌──────────────────────────┐  ┌──────────────────────────┐                              │
│  │    DONNEES_OEUFS         │  │   DONNEES_ALIMENT        │                              │
│  ├──────────────────────────┤  ├──────────────────────────┤                              │
│  │ PK id                    │  │ PK id                    │                              │
│  │ FK lot_id                │  │ FK lot_id                │                              │
│  │    date_mesure           │  │    date_mesure           │                              │
│  │    jour_age              │  │    jour_age              │                              │
│  │    nombre_oeufs          │  │    consommation_kg       │◄── totalFeedConsumption     │
│  │    taux_ponte            │  │    conso_par_animal      │◄── animalFeedConsumption    │
│  │    source                │  │    indice_conso          │◄── feedRate                 │
│  │    created_at            │  │    conso_cumul           │                              │
│  └──────────────────────────┘  │    source                │                              │
│                                │    created_at            │                              │
│                                └──────────────────────────┘                              │
│                                                                                          │
│  ┌──────────────────────────┐  ┌──────────────────────────┐                              │
│  │    DONNEES_EAU           │  │   DONNEES_AMBIANCE       │                              │
│  ├──────────────────────────┤  ├──────────────────────────┤                              │
│  │ PK id                    │  │ PK id                    │                              │
│  │ FK lot_id                │  │ FK lot_id                │                              │
│  │    date_mesure           │  │    date_mesure           │                              │
│  │    jour_age              │  │    jour_age              │                              │
│  │    consommation_litres   │  │    temperature           │◄── airTemperatureByProbe    │
│  │    conso_par_animal      │  │    hygrometrie           │◄── humidityByProbe          │
│  │    ratio_eau_aliment     │  │    co2                   │◄── co2 (si dispo)           │
│  │    conso_cumul           │  │    source                │                              │
│  │    source                │  │    created_at            │                              │
│  │    created_at            │  └──────────────────────────┘                              │
│  └──────────────────────────┘                                                            │
│                                                                                          │
│  ┌──────────────────────────┐                                                            │
│  │    DONNEES_ENERGIE       │  Données WindToFeed (silos, vannes, compteurs)             │
│  ├──────────────────────────┤                                                            │
│  │ PK id                    │                                                            │
│  │ FK lot_id                │                                                            │
│  │    date_mesure           │                                                            │
│  │    jour_age              │                                                            │
│  │    gaz_consommation      │◄── gas API                                                 │
│  │    electricite           │◄── electricity API                                         │
│  │    vitesse_air           │◄── speed API                                               │
│  │    source                │                                                            │
│  │    created_at            │                                                            │
│  └──────────────────────────┘                                                            │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              WINDTOFEED - ÉQUIPEMENTS                                    │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌──────────────────────────┐  ┌──────────────────────────┐                              │
│  │    COMPTEURS_EAU         │  │        SILOS             │                              │
│  ├──────────────────────────┤  ├──────────────────────────┤                              │
│  │ PK id                    │  │ PK id                    │                              │
│  │    tuffigo_id            │  │    tuffigo_id            │◄── id API                    │
│  │ FK batiment_id           │  │ FK batiment_id           │◄── building_id               │
│  │    nom                   │  │    nom                   │◄── name                      │
│  │    type                  │  │    type                  │◄── type                      │
│  │    created_at            │  │    formule               │◄── formula                   │
│  │    source                │  │    created_at            │                              │
│  └──────────────────────────┘  └──────────────────────────┘                              │
│                                                                                          │
│  ┌──────────────────────────┐  ┌──────────────────────────┐                              │
│  │  MESURES_COMPTEURS_EAU   │  │     MESURES_SILOS        │                              │
│  ├──────────────────────────┤  ├──────────────────────────┤                              │
│  │ PK id                    │  │ PK id                    │                              │
│  │ FK compteur_id           │  │ FK silo_id               │                              │
│  │ FK lot_id                │  │ FK lot_id                │                              │
│  │    date_mesure           │  │    date_mesure           │                              │
│  │    valeur                │  │    quantite_distribuee   │◄── quantityDistributed      │
│  │    consumption           │  │    humidite              │◄── humidityByProbe          │
│  │    created_at            │  │    created_at            │                              │
│  └──────────────────────────┘  └──────────────────────────┘                              │
│                                                                                          │
│  ┌──────────────────────────┐  ┌──────────────────────────┐                              │
│  │        VANNES            │  │     MESURES_VANNES       │                              │
│  ├──────────────────────────┤  ├──────────────────────────┤                              │
│  │ PK id                    │  │ PK id                    │                              │
│  │    tuffigo_id            │  │ FK vanne_id              │                              │
│  │ FK batiment_id           │  │ FK lot_id                │                              │
│  │    nom                   │  │    date_mesure           │                              │
│  │    room_id               │  │    quantite              │◄── quantity                  │
│  │    animal_kind           │  │    created_at            │                              │
│  │    created_at            │  └──────────────────────────┘                              │
│  └──────────────────────────┘                                                            │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              SYNCHRONISATION API                                         │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌──────────────────────────┐                                                            │
│  │      SYNC_LOGS           │  Journal de synchronisation avec l'API                     │
│  ├──────────────────────────┤                                                            │
│  │ PK id                    │                                                            │
│  │    type_entite           │  (eleveur, site, lot, donnees_poids, etc.)                 │
│  │    entite_id             │                                                            │
│  │    tuffigo_id            │                                                            │
│  │    action                │  (create, update, delete)                                  │
│  │    status                │  (success, error)                                          │
│  │    error_message         │                                                            │
│  │    synced_at             │                                                            │
│  └──────────────────────────┘                                                            │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 📋 Détail des Tables

### TABLES PRINCIPALES

#### 1. **API_CONFIG** — Mise à jour migration 012
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| api_key | VARCHAR(255) | NOT NULL | Token API — header `Authorization: token <api_key>` |
| **api_login** | TEXT | | **NOUVEAU 012** — Login portail web Tuffigo |
| **api_password** | TEXT | | **NOUVEAU 012** — Mot de passe portail web |
| base_url | VARCHAR(255) | DEFAULT `https://api.mytuffigorapidex.com/group/v2/` | **CORRIGÉ 012** |
| last_sync | TIMESTAMPTZ | | Dernière synchronisation réussie |
| is_active | BOOLEAN | DEFAULT true | Enregistrement actif |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Date de modification |

#### 2. **USERS** (Utilisateurs)
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| email | VARCHAR(255) | UNIQUE, NOT NULL | Email de connexion |
| password_hash | VARCHAR(255) | NOT NULL | Mot de passe hashé |
| nom | VARCHAR(100) | NOT NULL | Nom affiché |
| role | VARCHAR(20) | NOT NULL | `admin`, `technicien`, `eleveur` |
| is_active | BOOLEAN | DEFAULT true | Compte actif |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |
| last_login | TIMESTAMPTZ | | Dernière connexion |

#### 3. **ELEVEURS** — Enrichi migration 008
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique Supabase |
| tuffigo_id | INTEGER | UNIQUE | **breeder_id** de l'API Tuffigo |
| inrae_id | VARCHAR(50) | | Identifiant national unique |
| user_id | UUID | FK → users.id, NULLABLE | Lien vers compte utilisateur |
| code_eleveur | VARCHAR(20) | UNIQUE, NOT NULL | Code interne |
| nom | VARCHAR(100) | NOT NULL | Nom |
| prenom | VARCHAR(100) | | Prénom |
| raison_sociale | VARCHAR(200) | | Raison sociale |
| telephone | VARCHAR(20) | | Téléphone |
| email | VARCHAR(255) | | Email |
| siret | VARCHAR(14) | | SIRET |
| adresse_json | JSONB | | Adresse complète (address API) |
| permissions_json | JSONB | | Permissions (generalPermissions API) |
| statut_tuffigo | VARCHAR(20) | | État du compte Tuffigo |
| **nom_fournisseur** | TEXT | | **LEGACY 008** — Remplacé par fournisseurs_eleveur |
| **email_fournisseur** | TEXT | | **LEGACY 008** — Remplacé par fournisseurs_eleveur |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 4. **SITES** (= Élevages Tuffigo)
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique Supabase |
| tuffigo_id | INTEGER | UNIQUE | **breeding_id** de l'API |
| eleveur_id | UUID | FK → eleveurs.id, NOT NULL | Éleveur propriétaire |
| nom | VARCHAR(100) | NOT NULL | Nom du site |
| adresse | VARCHAR(255) | | Rue |
| code_postal | VARCHAR(10) | | Code postal |
| ville | VARCHAR(100) | | Ville |
| departement | VARCHAR(100) | | Département |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 5. **BATIMENTS**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique Supabase |
| tuffigo_id | INTEGER | UNIQUE | **building_id** de l'API |
| site_id | UUID | FK → sites.id, NOT NULL | Site parent |
| nom | VARCHAR(50) | NOT NULL | Nom du bâtiment |
| capacite | INTEGER | | Capacité maximale |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 6. **REGULATEURS**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique Supabase |
| tuffigo_id | INTEGER | UNIQUE | **id** de l'API (regulator) |
| batiment_id | UUID | FK → batiments.id, NOT NULL | Bâtiment |
| nom | VARCHAR(100) | NOT NULL | Nom |
| type | VARCHAR(50) | | Type (avitouch, etc.) |
| version | VARCHAR(20) | | Version du firmware |
| created_at_tuffigo | TIMESTAMPTZ | | Date création côté Tuffigo |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 7. **SOUCHES**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique Supabase |
| tuffigo_id | INTEGER | UNIQUE | **id** de l'API (strain) |
| nom | VARCHAR(50) | UNIQUE, NOT NULL | Nom |
| type | VARCHAR(50) | | `shared` ou `private` |
| description | TEXT | | Description |
| consignes_json | JSONB | | Consignes quotidiennes (data.daily API) |
| created_at_tuffigo | DATE | | Date création Tuffigo |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

---

### TABLES DE STANDARDS (liées aux souches)

#### 8-11. **STANDARDS_*** (4 tables — structure identique)

| Champ API | Table Supabase | Colonne |
|-----------|----------------|---------|
| weight | STANDARDS_POIDS | poids_min, poids_max |
| cumMortality | STANDARDS_MORTALITE | mortalite_min, mortalite_max |
| feedConsumption | STANDARDS_ALIMENT | conso_min, conso_max |
| (à définir) | STANDARDS_OEUFS | taux_min, taux_max |

**Structure commune :**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| souche_id | UUID | FK → souches.id, NOT NULL | Souche |
| jour_age | INTEGER | NOT NULL | Jour d'âge |
| valeur_min | DECIMAL | NOT NULL | Minimum standard |
| valeur_max | DECIMAL | NOT NULL | Maximum standard |
| date_effet | DATE | NOT NULL | Date d'entrée en vigueur |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

---

### TABLES DE LOTS

#### 12. **LOTS** (= Bandes Tuffigo)
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique Supabase |
| tuffigo_id | INTEGER | UNIQUE | **id** de l'API (batch) |
| batiment_id | UUID | FK → batiments.id, NOT NULL | Bâtiment |
| souche_id | UUID | FK → souches.id | Souche |
| code_lot | VARCHAR(20) | UNIQUE, NOT NULL | Code lot (name API) |
| effectif_depart | INTEGER | NOT NULL | Total animaux livrés |
| effectif_male | INTEGER | | Mâles livrés |
| effectif_femelle | INTEGER | | Femelles livrées |
| date_mise_place | DATE | NOT NULL | entranceDate API |
| date_sortie_prevue | DATE | | exitDate API |
| statut | VARCHAR(20) | DEFAULT 'actif' | `actif`, `termine`, `archive` |
| couvoir_id | VARCHAR(50) | | hatchery_id API |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 13. **PRE_BANDES**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| tuffigo_id | INTEGER | UNIQUE | id API (presetbatch) |
| eleveur_id | UUID | FK → eleveurs.id | Éleveur |
| batiment_id | UUID | FK → batiments.id | Bâtiment cible |
| souche_id | UUID | FK → souches.id | Souche prévue |
| nom | VARCHAR(100) | NOT NULL | Nom de la pré-bande |
| effectif_male | INTEGER | | Mâles prévus |
| effectif_femelle | INTEGER | | Femelles prévues |
| date_entree_prevue | DATE | | Date d'entrée prévue |
| date_sortie_prevue | DATE | | Date de sortie prévue |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

---

### TABLES COMMANDES D'ALIMENT (NOUVEAU — migrations 008-011)

#### 14. **TYPES_ALIMENT** — Enrichi migration 011
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| **code_aliment** | TEXT | **UNIQUE (011)** | Code interne aliment (ex: ALI-001) |
| nom | TEXT | NOT NULL | Libellé de l'aliment |
| **categorie** | TEXT | | **NOUVEAU 011** — Catégorie (Démarrage, Croissance…) |
| **unite** | TEXT | NOT NULL DEFAULT 'tonnes' | **NOUVEAU 011** — Unité de commande |
| description | TEXT | | Description complémentaire |
| is_active | BOOLEAN | NOT NULL DEFAULT true | Visible dans les commandes |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 15. **FOURNISSEURS_ELEVEUR** — Migrations 009 + 010
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| eleveur_id | UUID | FK → eleveurs.id NOT NULL CASCADE | Éleveur propriétaire |
| nom | TEXT | NOT NULL | Nom du fournisseur |
| rue | TEXT | | **NOUVEAU 010** — N° et voie (remplace `adresse`) |
| code_postal | TEXT | | **NOUVEAU 010** — Code postal |
| ville | TEXT | | **NOUVEAU 010** — Ville |
| contact_nom | TEXT | | Nom du contact |
| email | TEXT | NOT NULL | Email pour envoi des commandes |
| is_active | BOOLEAN | NOT NULL DEFAULT true | Fournisseur actif |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Date de modification |

#### 16. **COMMANDES_ALIMENT** — Migration 008 + 009
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| eleveur_id | UUID | FK → eleveurs.id NOT NULL CASCADE | Éleveur commanditaire |
| type_aliment_id | UUID | FK → types_aliment.id NULLABLE | Type d'aliment commandé |
| **fournisseur_eleveur_id** | UUID | **FK → fournisseurs_eleveur.id (009)** | Fournisseur sélectionné |
| quantite | NUMERIC | NOT NULL CHECK (> 0) | Quantité commandée |
| unite | TEXT | NOT NULL DEFAULT 'tonnes' | Unité (reportée de types_aliment) |
| date_livraison_souhaitee | DATE | NOT NULL | Date souhaitée par l'éleveur |
| date_livraison_confirmee | DATE | | Date confirmée par le fournisseur |
| heure_livraison_confirmee | TEXT | | Heure confirmée (HH:MM) |
| statut | TEXT | CHECK IN ('en_attente','confirmee','livree','annulee') | État de la commande |
| notes | TEXT | | Instructions particulières |
| confirmation_token | UUID | UNIQUE DEFAULT gen_random_uuid() | Token lien confirm.html |
| confirmation_token_expire_at | TIMESTAMPTZ | DEFAULT now()+30 jours | Expiration du token |
| email_envoye_at | TIMESTAMPTZ | | Date d'envoi de l'email |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Date de modification |

---

### TABLES DE DONNÉES DE PRODUCTION

#### 17. **DONNEES_POIDS**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| lot_id | UUID | FK → lots.id, NOT NULL | Lot |
| date_mesure | DATE | NOT NULL | Date |
| jour_age | INTEGER | NOT NULL | Jour d'âge |
| poids_moyen | DECIMAL(10,2) | NOT NULL | Poids moyen global (g) |
| poids_moyen_male | DECIMAL(10,2) | | Poids moyen mâles |
| poids_moyen_femelle | DECIMAL(10,2) | | Poids moyen femelles |
| nb_pesees | INTEGER | | Nombre de pesées du jour |
| homogeneite | DECIMAL(5,2) | | Homogénéité (%) |
| objectif_poids | DECIMAL(10,2) | | Objectif poids (de la souche) |
| nb_pesees_total | INTEGER | | Nombre de pesées cumulé |
| source | VARCHAR(20) | DEFAULT 'tuffigo' | `tuffigo` ou `manuel` |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 18. **DONNEES_MORTALITE**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| lot_id | UUID | FK → lots.id, NOT NULL | Lot |
| date_mesure | DATE | NOT NULL | Date |
| jour_age | INTEGER | NOT NULL | Jour d'âge |
| nombre_morts | INTEGER | NOT NULL | Total morts du jour |
| morts_male | INTEGER | | Morts mâles |
| morts_femelle | INTEGER | | Morts femelles |
| morts_elimines | INTEGER | | Éliminés |
| morts_malades | INTEGER | | Morts cardiaques |
| effectif_actuel | INTEGER | | Effectif restant |
| taux_mortalite_cumul | DECIMAL(5,4) | | Taux cumulé |
| source | VARCHAR(20) | DEFAULT 'tuffigo' | Source des données |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 19. **DONNEES_OEUFS**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| lot_id | UUID | FK → lots.id, NOT NULL | Lot |
| date_mesure | DATE | NOT NULL | Date |
| jour_age | INTEGER | NOT NULL | Jour d'âge |
| nombre_oeufs | INTEGER | NOT NULL | Nombre d'œufs |
| taux_ponte | DECIMAL(5,4) | | Taux de ponte |
| source | VARCHAR(20) | DEFAULT 'manuel' | Source des données |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 20. **DONNEES_ALIMENT**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| lot_id | UUID | FK → lots.id, NOT NULL | Lot |
| date_mesure | DATE | NOT NULL | Date |
| jour_age | INTEGER | NOT NULL | Jour d'âge |
| consommation_kg | DECIMAL(10,2) | NOT NULL | Conso totale (kg) |
| conso_par_animal | DECIMAL(10,4) | | Conso par animal (g) |
| indice_conso | DECIMAL(6,3) | | Indice de consommation |
| conso_cumul | DECIMAL(12,2) | | Consommation cumulée |
| source | VARCHAR(20) | DEFAULT 'tuffigo' | Source |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 21. **DONNEES_EAU**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| lot_id | UUID | FK → lots.id, NOT NULL | Lot |
| date_mesure | DATE | NOT NULL | Date |
| jour_age | INTEGER | NOT NULL | Jour d'âge |
| consommation_litres | DECIMAL(12,2) | NOT NULL | Conso totale (L) |
| conso_par_animal | DECIMAL(10,4) | | Conso par animal (ml) |
| ratio_eau_aliment | DECIMAL(6,3) | | Ratio eau/aliment |
| conso_cumul | DECIMAL(14,2) | | Consommation cumulée |
| source | VARCHAR(20) | DEFAULT 'tuffigo' | Source |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 22. **DONNEES_AMBIANCE**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| lot_id | UUID | FK → lots.id, NOT NULL | Lot |
| date_mesure | DATE | NOT NULL | Date |
| jour_age | INTEGER | NOT NULL | Jour d'âge |
| temperature | DECIMAL(5,2) | | Température (°C) |
| hygrometrie | DECIMAL(5,2) | | Hygrométrie (%) |
| co2 | INTEGER | | CO2 (ppm) |
| source | VARCHAR(20) | DEFAULT 'tuffigo' | Source |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 23. **DONNEES_ENERGIE**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| lot_id | UUID | FK → lots.id, NOT NULL | Lot |
| date_mesure | DATE | NOT NULL | Date |
| jour_age | INTEGER | NOT NULL | Jour d'âge |
| gaz_consommation | DECIMAL(10,2) | | Consommation gaz |
| electricite | DECIMAL(10,2) | | Consommation électricité |
| vitesse_air | DECIMAL(8,2) | | Vitesse d'air |
| source | VARCHAR(20) | DEFAULT 'tuffigo' | Source |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

---

### TABLES WINDTOFEED (Équipements)

#### 24-29. Tables d'équipements WindToFeed

| Table | Description |
|-------|-------------|
| SILOS | Silos d'aliment |
| MESURES_SILOS | Mesures des silos |
| COMPTEURS_EAU | Compteurs d'eau |
| MESURES_COMPTEURS_EAU | Mesures des compteurs |
| VANNES | Vannes d'alimentation |
| MESURES_VANNES | Mesures des vannes |

---

### TABLE DE SYNCHRONISATION

#### 30. **SYNC_LOGS**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| type_entite | VARCHAR(50) | NOT NULL | Type (eleveur, lot, commande, etc.) |
| entite_id | UUID | | ID Supabase |
| tuffigo_id | INTEGER | | ID Tuffigo |
| action | VARCHAR(20) | NOT NULL | create, update, delete |
| status | VARCHAR(20) | NOT NULL | success, error |
| error_message | TEXT | | Message d'erreur |
| synced_at | TIMESTAMPTZ | DEFAULT NOW() | Date de synchro |

---

## 📊 Résumé : 30 Tables + 1 Vue

| Catégorie | Tables | Migration |
|-----------|--------|-----------|
| Configuration | api_config | 001 + **012** (api_login, api_password, base_url) |
| Utilisateurs | users, eleveurs | 001 + **008** (nom/email_fournisseur legacy) |
| Infrastructure | sites, batiments, regulateurs | 001-003 |
| Référentiel | souches | 001 |
| Standards | standards_poids, standards_mortalite, standards_oeufs, standards_aliment | 002 |
| Lots | lots, pre_bandes | 002-003 |
| **Commandes** | **types_aliment** | **008 + 011** (code, catégorie, unité) |
| **Fournisseurs** | **fournisseurs_eleveur** | **009 + 010** (adresse décomposée) |
| **Commandes** | **commandes_aliment** | **008 + 009** (fournisseur_eleveur_id) |
| Données production | donnees_poids, donnees_mortalite, donnees_oeufs, donnees_aliment, donnees_eau, donnees_ambiance, donnees_energie | 003 |
| WindToFeed | silos, mesures_silos, compteurs_eau, mesures_compteurs_eau, vannes, mesures_vannes | 003 |
| Synchronisation | sync_logs | 003 |
| **Vues** | **v_planning_commandes** | **008 + 009** |

**Total : 30 tables** + 1 vue (vs 27 en version 2.0)

---

## 🔗 Relations entre les nouvelles tables

```
eleveurs (1) ────────────── (n) fournisseurs_eleveur
    │                                   │ 0,n
    │ 1,n                               │
    ▼                                   ▼
commandes_aliment (n) ─── (1) types_aliment
    │
    └── fournisseur_eleveur_id (FK) ──► fournisseurs_eleveur
    └── eleveur_id (FK)              ──► eleveurs
    └── type_aliment_id (FK)         ──► types_aliment
    └── confirmation_token            ──► lien confirm.html (public, sans auth)
```

---

## 🔄 Mapping API Tuffigo → Supabase

### Endpoints et Tables (API v2)

| Endpoint API | Table Supabase |
|-------------|----------------|
| GET /group/v2/breeders/ | eleveurs |
| GET /group/v2/breeders/{id} | eleveurs (détail) |
| GET /group/v2/breeders/{id}/breedings/ | sites |
| GET /group/v2/breeders/{id}/buildings/ | batiments |
| GET /group/v2/breeders/{id}/batchs/ | lots |
| GET /group/v2/breeders/{id}/controllers | regulateurs |
| GET /group/v2/breedings/{id} | sites (détail) |
| GET /group/v2/breedings/{id}/buildings/ | batiments |
| GET /group/v2/breedings/{id}/batchs/ | lots |
| GET /group/v2/buildings/{id}/batchs/ | lots |
| GET /group/v2/batchs/{id} | lots + données production |
| GET /group/v2/batchs/{id}/measures/?date=YYYY-MM-DD | données mesures 15min |
| GET /group/v2/presetbatchs/ | pre_bandes |
| POST /group/v2/presetbatchs/ | pre_bandes (création) |
| GET /group/v2/strains/ | souches |
| GET /group/v2/strains/{id} | souches + standards |
| GET /group/v2/controllers/{id}/water_meters | compteurs_eau + mesures |
| GET /group/v2/controllers/{id}/silos | silos + mesures |
| GET /group/v2/controllers/{id}/valves | vannes + mesures |

### Données de Production (batchs.data)

| Thématique API | Tables Supabase |
|----------------|-----------------|
| consumption.food | donnees_aliment |
| consumption.water | donnees_eau |
| sensor (ambiance) | donnees_ambiance |
| animals[].weight + adg | donnees_poids |
| animals[].dead + eliminated | donnees_mortalite |
| silos | mesures_silos |

---

## 💡 Flux de Synchronisation

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SYNCHRONISATION TUFFIGO → SUPABASE               │
│  Base URL : https://api.mytuffigorapidex.com/group/v2/              │
│  Header   : Authorization: token <api_config.api_key>               │
└─────────────────────────────────────────────────────────────────────┘

1. SYNC INITIALE (au démarrage)
   └─► GET /breeders/ → eleveurs
       └─► Pour chaque éleveur:
           ├─► GET /breeders/{id}/breedings/ → sites
           ├─► GET /breeders/{id}/buildings/ → batiments
           ├─► GET /breeders/{id}/controllers → regulateurs
           └─► GET /breeders/{id}/batchs/    → lots

2. SYNC SOUCHES
   └─► GET /strains/ → souches + standards_*

3. SYNC DONNÉES PRODUCTION (périodique)
   └─► Pour chaque lot actif:
       └─► GET /batchs/{batch_id}
           ├─► data.consumption.food  → donnees_aliment
           ├─► data.consumption.water → donnees_eau
           ├─► data.sensor            → donnees_ambiance
           ├─► data.animals[].dead    → donnees_mortalite
           └─► data.animals[].weight  → donnees_poids

4. SYNC MESURES TEMPS RÉEL (optionnel, 15min)
   └─► GET /batchs/{batch_id}/measures/?date=YYYY-MM-DD
       └─► Données détaillées par capteur

5. SYNC WINDTOFEED (si activé)
   ├─► GET /controllers/{id}/water_meters → compteurs_eau + mesures
   ├─► GET /controllers/{id}/silos        → silos + mesures
   └─► GET /controllers/{id}/valves       → vannes + mesures
```

---

## 📝 Historique des migrations

| Migration | Description |
|-----------|-------------|
| 000_install | Extensions PostgreSQL |
| 001_create_tables_part1 | api_config, users, eleveurs |
| 002_create_tables_part2 | souches, standards_*, lots, pre_bandes |
| 003_create_tables_part3 | données production, WindToFeed, sync_logs |
| 004_create_views | Vues de synthèse |
| 005_create_rls_policies | Politiques RLS Supabase |
| 006_seed_data | Données initiales |
| 007_create_rpc_functions | Fonctions RPC Supabase |
| **008_commandes_aliment** | types_aliment, commandes_aliment, v_planning_commandes, colonnes legacy eleveurs |
| **009_fournisseurs_eleveur** | fournisseurs_eleveur, FK fournisseur_eleveur_id sur commandes_aliment, màj vue |
| **010_fournisseurs_adresse_decomposee** | Découpage adresse → rue + code_postal + ville |
| **011_types_aliment_enrichissement** | code_aliment (UNIQUE), categorie, unite sur types_aliment |
| **012_api_config_credentials** | api_login, api_password sur api_config, correction base_url |
