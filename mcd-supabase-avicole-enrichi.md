# Modèle Conceptuel de Données - Suivi Production Avicole
## Enrichi avec l'API Tuffigo Rapidex

---

## 📊 Synthèse des Entités de l'API Tuffigo Rapidex

D'après la documentation, voici la hiérarchie des données :

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

---

## 🗂️ Schéma Relationnel Complet

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           MODÈLE DE DONNÉES ENRICHI TUFFIGO                             │
└─────────────────────────────────────────────────────────────────────────────────────────┘

                                    AUTHENTIFICATION
┌──────────────────┐
│   API_CONFIG     │  Configuration de connexion à l'API Tuffigo
├──────────────────┤
│ PK id            │
│    api_key       │
│    base_url      │
│    last_sync     │
│    created_at    │
└──────────────────┘

                                    UTILISATEURS
┌──────────────────┐       ┌──────────────────┐
│     USERS        │       │    ELEVEURS      │
├──────────────────┤       ├──────────────────┤
│ PK id            │       │ PK id            │
│    email         │       │    tuffigo_id    │◄── breeder_id API
│    password_hash │◄──────│ FK user_id       │
│    nom           │  0,1  │    inrae_id      │◄── Identifiant national (SIRET)
│    role          │       │    code_eleveur  │
│    created_at    │       │    nom           │
│    last_login    │       │    prenom        │
└──────────────────┘       │    raison_sociale│
                           │    telephone     │
                           │    email         │
                           │    siret         │◄── siret API
                           │    adresse       │◄── address API
                           │    permissions   │◄── generalPermissions API
                           │    created_at    │
                           └──────────────────┘
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
│  │    created_at_tf │◄── date API                                                        │
│  │    created_at    │                                                                    │
│  └──────────────────┘                                                                    │
│           │                                                                              │
│           │ 1,n (standards par jour d'âge - issus de data.daily dans l'API)              │
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
│                          DONNÉES DE PRODUCTION (depuis l'API)                            │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  Les données sont regroupées en 5 thématiques dans l'API :                               │
│  - consumption : Consommations des animaux (eau, aliment)                                │
│  - ambiance : Ambiance du bâtiment (température, hygrométrie, CO2)                       │
│  - energy : Consommation du bâtiment (gaz, électricité, vitesse)                         │
│  - animals_mortality : Mortalité                                                         │
│  - animals_weight : Poids                                                                │
│                                                                                          │
│  ┌──────────────────────────┐  ┌──────────────────────────┐                              │
│  │    DONNEES_POIDS         │  │   DONNEES_MORTALITE      │                              │
│  ├──────────────────────────┤  ├──────────────────────────┤                              │
│  │ PK id                    │  │ PK id                    │                              │
│  │ FK lot_id                │  │ FK lot_id                │                              │
│  │    date_mesure           │  │    date_mesure           │                              │
│  │    jour_age              │  │    jour_age              │                              │
│  │    poids_moyen           │◄─│    nombre_morts          │◄── totalDeadAnimals         │
│  │    poids_moyen_male      │  │    morts_male            │◄── animals[male].dead       │
│  │    poids_moyen_femelle   │  │    morts_femelle         │◄── animals[female].dead     │
│  │    nb_pesees             │  │    morts_elimines        │◄── animals[].eliminated     │
│  │    homogeneite           │◄─│    morts_malades         │◄── animals[].cardiacDeath   │
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
│  │    created_at            │  │    conso_cumul           │◄── totalFeedConsumption     │
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
│  │    consommation_litres   │◄─│    temperature           │◄── airTemperatureByProbe    │
│  │    conso_par_animal      │  │    hygrometrie           │◄── humidityByProbe          │
│  │    ratio_eau_aliment     │◄─│    co2                   │◄── co2 (si dispo)           │
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
│  │    tuffigo_id            │◄─│    tuffigo_id            │◄── id API                    │
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
│  │    valeur                │◄─│    quantite_distribuee   │◄── quantityDistributed      │
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

#### 1. **API_CONFIG** (Configuration API Tuffigo)
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| api_key | VARCHAR(255) | NOT NULL, ENCRYPTED | Clé API Tuffigo |
| base_url | VARCHAR(255) | DEFAULT 'https://api.mytuffigorapidex.com' | URL de base |
| last_sync | TIMESTAMPTZ | | Dernière synchronisation |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 2. **USERS** (Utilisateurs - inchangé)
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| email | VARCHAR(255) | UNIQUE, NOT NULL | Email de connexion |
| password_hash | VARCHAR(255) | NOT NULL | Mot de passe hashé |
| nom | VARCHAR(100) | NOT NULL | Nom affiché |
| role | VARCHAR(20) | NOT NULL | 'admin', 'technicien', 'eleveur' |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |
| last_login | TIMESTAMPTZ | | Dernière connexion |

#### 3. **ELEVEURS** (Enrichi avec données Tuffigo)
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique Supabase |
| **tuffigo_id** | INTEGER | UNIQUE | **breeder_id** de l'API Tuffigo |
| **inrae_id** | VARCHAR(50) | | Identifiant national unique (SIRET) |
| user_id | UUID | FK → users.id, NULLABLE | Lien vers compte utilisateur |
| code_eleveur | VARCHAR(20) | UNIQUE, NOT NULL | Code interne |
| nom | VARCHAR(100) | NOT NULL | Nom (name API) |
| prenom | VARCHAR(100) | | Prénom (firstName API) |
| raison_sociale | VARCHAR(200) | | Raison sociale (company API) |
| telephone | VARCHAR(20) | | Téléphone |
| email | VARCHAR(255) | | Email (email API) |
| **siret** | VARCHAR(14) | | SIRET (siret API) |
| **adresse_json** | JSONB | | Adresse complète (address API) |
| **permissions_json** | JSONB | | Permissions (generalPermissions API) |
| **statut_tuffigo** | VARCHAR(20) | | État du compte Tuffigo |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 4. **SITES** (= Élevages Tuffigo)
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique Supabase |
| **tuffigo_id** | INTEGER | UNIQUE | **breeding_id** de l'API |
| eleveur_id | UUID | FK → eleveurs.id, NOT NULL | Éleveur propriétaire |
| nom | VARCHAR(100) | NOT NULL | Nom du site (name API) |
| adresse | VARCHAR(255) | | Rue (address.street API) |
| code_postal | VARCHAR(10) | | Code postal (address.zipCode API) |
| ville | VARCHAR(100) | | Ville (address.city API) |
| departement | VARCHAR(100) | | Département |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 5. **BATIMENTS** (Enrichi)
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique Supabase |
| **tuffigo_id** | INTEGER | UNIQUE | **building_id** de l'API |
| site_id | UUID | FK → sites.id, NOT NULL | Site parent |
| nom | VARCHAR(50) | NOT NULL | Nom du bâtiment (name API) |
| capacite | INTEGER | | Capacité maximale |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 6. **REGULATEURS** (Nouveau - Régulateurs Tuffigo)
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique Supabase |
| **tuffigo_id** | INTEGER | UNIQUE | **id** de l'API (regulator) |
| batiment_id | UUID | FK → batiments.id, NOT NULL | Bâtiment |
| nom | VARCHAR(100) | NOT NULL | Nom (name API) |
| type | VARCHAR(50) | | Type (avitouch, etc.) |
| version | VARCHAR(20) | | Version du firmware |
| **created_at_tuffigo** | TIMESTAMPTZ | | Date création côté Tuffigo |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 7. **SOUCHES** (Enrichi avec données Tuffigo)
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique Supabase |
| **tuffigo_id** | INTEGER | UNIQUE | **id** de l'API (strain) |
| nom | VARCHAR(50) | UNIQUE, NOT NULL | Nom (name API) |
| type | VARCHAR(50) | | 'shared' ou 'private' |
| description | TEXT | | Description |
| **consignes_json** | JSONB | | Consignes quotidiennes (data.daily API) |
| **created_at_tuffigo** | DATE | | Date création Tuffigo (date API) |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

---

### TABLES DE STANDARDS (liées aux souches)

#### 8-11. **STANDARDS_*** (4 tables - structure identique)

Les consignes de la souche (via `data.daily` de l'API) contiennent pour chaque jour :

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
| **tuffigo_id** | INTEGER | UNIQUE | **id** de l'API (batch) |
| batiment_id | UUID | FK → batiments.id, NOT NULL | Bâtiment |
| souche_id | UUID | FK → souches.id | Souche (strain.id API) |
| code_lot | VARCHAR(20) | UNIQUE, NOT NULL | Code lot (name API) |
| effectif_depart | INTEGER | NOT NULL | Total animaux livrés |
| **effectif_male** | INTEGER | | Mâles livrés (animals[male].delivered) |
| **effectif_femelle** | INTEGER | | Femelles livrées (animals[female].delivered) |
| date_mise_place | DATE | NOT NULL | entranceDate API |
| **date_sortie_prevue** | DATE | | exitDate API |
| statut | VARCHAR(20) | DEFAULT 'actif' | 'actif', 'termine', 'archive' |
| **couvoir_id** | VARCHAR(50) | | hatchery_id API |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 13. **PRE_BANDES** (Nouveau - Préparation des lots)
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

### TABLES DE DONNÉES DE PRODUCTION

#### 14. **DONNEES_POIDS** (Enrichi)
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| lot_id | UUID | FK → lots.id, NOT NULL | Lot |
| date_mesure | DATE | NOT NULL | Date |
| jour_age | INTEGER | NOT NULL | Jour d'âge |
| poids_moyen | DECIMAL(10,2) | NOT NULL | Poids moyen global (g) |
| **poids_moyen_male** | DECIMAL(10,2) | | Poids moyen mâles |
| **poids_moyen_femelle** | DECIMAL(10,2) | | Poids moyen femelles |
| **nb_pesees** | INTEGER | | Nombre de pesées du jour |
| **homogeneite** | DECIMAL(5,2) | | Homogénéité (%) |
| **objectif_poids** | DECIMAL(10,2) | | Objectif poids (de la souche) |
| **nb_pesees_total** | INTEGER | | Nombre de pesées cumulé |
| **source** | VARCHAR(20) | DEFAULT 'tuffigo' | 'tuffigo' ou 'manuel' |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 15. **DONNEES_MORTALITE** (Enrichi)
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| lot_id | UUID | FK → lots.id, NOT NULL | Lot |
| date_mesure | DATE | NOT NULL | Date |
| jour_age | INTEGER | NOT NULL | Jour d'âge |
| nombre_morts | INTEGER | NOT NULL | Total morts du jour |
| **morts_male** | INTEGER | | Morts mâles |
| **morts_femelle** | INTEGER | | Morts femelles |
| **morts_elimines** | INTEGER | | Éliminés |
| **morts_malades** | INTEGER | | Morts cardiaques |
| effectif_actuel | INTEGER | | Effectif restant |
| **taux_mortalite_cumul** | DECIMAL(5,4) | | Taux cumulé |
| **source** | VARCHAR(20) | DEFAULT 'tuffigo' | Source des données |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 16. **DONNEES_OEUFS**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| lot_id | UUID | FK → lots.id, NOT NULL | Lot |
| date_mesure | DATE | NOT NULL | Date |
| jour_age | INTEGER | NOT NULL | Jour d'âge |
| nombre_oeufs | INTEGER | NOT NULL | Nombre d'œufs |
| taux_ponte | DECIMAL(5,4) | | Taux de ponte |
| **source** | VARCHAR(20) | DEFAULT 'manuel' | Source des données |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 17. **DONNEES_ALIMENT** (Enrichi)
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| lot_id | UUID | FK → lots.id, NOT NULL | Lot |
| date_mesure | DATE | NOT NULL | Date |
| jour_age | INTEGER | NOT NULL | Jour d'âge |
| consommation_kg | DECIMAL(10,2) | NOT NULL | Conso totale (kg) |
| **conso_par_animal** | DECIMAL(10,4) | | Conso par animal (g) |
| **indice_conso** | DECIMAL(6,3) | | Indice de consommation |
| **conso_cumul** | DECIMAL(12,2) | | Consommation cumulée |
| **source** | VARCHAR(20) | DEFAULT 'tuffigo' | Source |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Date de création |

#### 18. **DONNEES_EAU** (Nouveau)
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

#### 19. **DONNEES_AMBIANCE** (Nouveau)
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

#### 20. **DONNEES_ENERGIE** (Nouveau)
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

#### 21-26. Tables d'équipements WindToFeed

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

#### 27. **SYNC_LOGS**
| Colonne | Type | Contraintes | Description |
|---------|------|-------------|-------------|
| id | UUID | PK | Identifiant unique |
| type_entite | VARCHAR(50) | NOT NULL | Type (eleveur, lot, etc.) |
| entite_id | UUID | | ID Supabase |
| tuffigo_id | INTEGER | | ID Tuffigo |
| action | VARCHAR(20) | NOT NULL | create, update, delete |
| status | VARCHAR(20) | NOT NULL | success, error |
| error_message | TEXT | | Message d'erreur |
| synced_at | TIMESTAMPTZ | DEFAULT NOW() | Date de synchro |

---

## 🔄 Mapping API Tuffigo → Supabase

### Endpoints et Tables

| Endpoint API | Table Supabase |
|-------------|----------------|
| GET /breeders | eleveurs |
| GET /breeders/{id} | eleveurs (détail) |
| GET /breeders/{id}/breedings | sites |
| GET /breeders/{id}/buildings | batiments |
| GET /breeders/{id}/batchs | lots |
| GET /breeders/{id}/regulators | regulateurs |
| GET /breedings/{id} | sites (détail) |
| GET /breedings/{id}/buildings | batiments |
| GET /breedings/{id}/batchs | lots |
| GET /buildings/{id}/batchs | lots |
| GET /buildings/{id}/batch/{id} | lots + données production |
| GET /presetbatchs | pre_bandes |
| GET /strains | souches |
| GET /strains/{id} | souches + standards |
| GET /windtofeed/watermeters | compteurs_eau + mesures |
| GET /windtofeed/silos | silos + mesures |
| GET /windtofeed/valves | vannes + mesures |

### Données de Production (batch.data)

| Thématique API | Tables Supabase |
|----------------|-----------------|
| consumption | donnees_aliment, donnees_eau |
| ambiance | donnees_ambiance |
| energy | donnees_energie |
| animals_mortality | donnees_mortalite |
| animals_weight | donnees_poids |

---

## 📊 Résumé : 27 Tables

| Catégorie | Tables | Nouvelles |
|-----------|--------|-----------|
| Configuration | api_config | ✅ |
| Utilisateurs | users, eleveurs | +enrichi |
| Infrastructure | sites, batiments, regulateurs | +1 nouvelle |
| Référentiel | souches | +enrichi |
| Standards | standards_poids, standards_mortalite, standards_oeufs, standards_aliment | - |
| Lots | lots, pre_bandes | +1 nouvelle |
| Données production | donnees_poids, donnees_mortalite, donnees_oeufs, donnees_aliment, donnees_eau, donnees_ambiance, donnees_energie | +3 nouvelles |
| WindToFeed | silos, mesures_silos, compteurs_eau, mesures_compteurs_eau, vannes, mesures_vannes | +6 nouvelles |
| Synchronisation | sync_logs | ✅ |

**Total : 27 tables** (vs 14 initialement)

---

## 💡 Flux de Synchronisation

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SYNCHRONISATION TUFFIGO → SUPABASE               │
└─────────────────────────────────────────────────────────────────────┘

1. SYNC INITIALE (au démarrage)
   └─► GET /breeders → eleveurs
       └─► Pour chaque éleveur:
           ├─► GET /breeders/{id}/breedings → sites
           ├─► GET /breeders/{id}/buildings → batiments
           ├─► GET /breeders/{id}/regulators → regulateurs
           └─► GET /breeders/{id}/batchs → lots

2. SYNC SOUCHES
   └─► GET /strains → souches + standards_*

3. SYNC DONNÉES PRODUCTION (périodique)
   └─► Pour chaque lot actif:
       └─► GET /buildings/{building_id}/batch/{batch_id}
           ├─► data.consumption → donnees_aliment, donnees_eau
           ├─► data.ambiance → donnees_ambiance
           ├─► data.energy → donnees_energie
           ├─► data.animals_mortality → donnees_mortalite
           └─► data.animals_weight → donnees_poids

4. SYNC WINDTOFEED (si activé)
   ├─► GET /windtofeed/watermeters → compteurs_eau + mesures
   ├─► GET /windtofeed/silos → silos + mesures
   └─► GET /windtofeed/valves → vannes + mesures
```
