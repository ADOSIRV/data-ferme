# Scripts SQL - Suivi Production Avicole

## 📁 Structure des fichiers

```
sql/
├── 000_install.sql              # Script maître (ordre d'exécution)
├── 001_create_tables_part1.sql  # Tables principales
├── 002_create_tables_part2.sql  # Tables données de production
├── 003_create_tables_part3.sql  # Tables WindToFeed + sync
├── 004_create_views.sql         # Vues pour l'application
├── 005_create_rls_policies.sql  # Politiques de sécurité RLS
└── 006_seed_data.sql            # Données de test
```

## 🚀 Installation

### Option 1 : Via l'interface Supabase (recommandé)

1. Connectez-vous à votre projet Supabase
2. Allez dans **SQL Editor** (menu de gauche)
3. Cliquez sur **New query**
4. Exécutez les scripts **dans l'ordre** :

```
001 → 002 → 003 → 004 → 005 → 006 (optionnel)
```

### Option 2 : Via psql en ligne de commande

```bash
# Connexion à Supabase
psql "postgresql://postgres:[PASSWORD]@db.[PROJECT_REF].supabase.co:5432/postgres"

# Exécuter les scripts
\i 001_create_tables_part1.sql
\i 002_create_tables_part2.sql
\i 003_create_tables_part3.sql
\i 004_create_views.sql
\i 005_create_rls_policies.sql
\i 006_seed_data.sql
```

## 📊 Tables créées (27 tables)

### Configuration
| Table | Description |
|-------|-------------|
| `api_config` | Configuration API Tuffigo |

### Utilisateurs & Éleveurs
| Table | Description |
|-------|-------------|
| `users` | Utilisateurs de l'application |
| `eleveurs` | Éleveurs (breeder API) |

### Infrastructure
| Table | Description |
|-------|-------------|
| `sites` | Sites d'exploitation (breeding API) |
| `batiments` | Bâtiments d'élevage (building API) |
| `regulateurs` | Régulateurs Tuffigo |

### Souches & Standards
| Table | Description |
|-------|-------------|
| `souches` | Souches de volailles (strains API) |
| `standards_poids` | Standards poids par souche/âge |
| `standards_mortalite` | Standards mortalité par souche/âge |
| `standards_oeufs` | Standards œufs par souche/âge |
| `standards_aliment` | Standards aliment par souche/âge |

### Lots
| Table | Description |
|-------|-------------|
| `lots` | Lots de volailles (batch API) |
| `pre_bandes` | Pré-bandes (presetbatchs API) |

### Données de Production
| Table | Description |
|-------|-------------|
| `donnees_poids` | Mesures de poids |
| `donnees_mortalite` | Mesures de mortalité |
| `donnees_oeufs` | Production d'œufs |
| `donnees_aliment` | Consommation d'aliment |
| `donnees_eau` | Consommation d'eau |
| `donnees_ambiance` | Température, hygrométrie |
| `donnees_energie` | Gaz, électricité |

### WindToFeed
| Table | Description |
|-------|-------------|
| `silos` | Silos d'aliment |
| `mesures_silos` | Mesures des silos |
| `compteurs_eau` | Compteurs d'eau |
| `mesures_compteurs_eau` | Mesures compteurs |
| `vannes` | Vannes d'alimentation |
| `mesures_vannes` | Mesures des vannes |

### Synchronisation
| Table | Description |
|-------|-------------|
| `sync_logs` | Journal de synchronisation |

## 👁️ Vues créées

| Vue | Description |
|-----|-------------|
| `v_lots_eleveur` | Lots avec infos complètes |
| `v_donnees_poids_avec_standards` | Poids + comparaison standards |
| `v_donnees_mortalite_avec_standards` | Mortalité + comparaison |
| `v_donnees_aliment_avec_standards` | Aliment + comparaison |
| `v_donnees_oeufs_avec_standards` | Œufs + comparaison |
| `v_donnees_graphique` | Vue consolidée pour graphiques |
| `v_resume_lot` | Résumé performances d'un lot |
| `v_alertes_lot` | Alertes (écarts aux standards) |

## 🔐 Sécurité (RLS)

Les politiques Row Level Security sont configurées pour :

| Rôle | Accès |
|------|-------|
| **admin** | Accès total à toutes les données |
| **technicien** | Lecture de tous les éleveurs, modification limitée |
| **eleveur** | Uniquement ses propres données |

## 🧪 Données de test

Le script `006_seed_data.sql` crée :

- 4 utilisateurs (1 admin, 1 technicien, 2 éleveurs)
- 3 éleveurs
- 2 sites
- 3 bâtiments
- 6 souches de référence
- 71 jours de standards (Ross 308)
- 2 lots actifs
- ~60 jours de données de production

## ⚠️ Notes importantes

1. **Ordre d'exécution** : Respectez l'ordre des scripts (clés étrangères)
2. **Authentification** : En production, utilisez Supabase Auth
3. **RLS** : Les politiques sont activées, testez avec différents utilisateurs
4. **Seed** : Le script 006 est optionnel (données de test uniquement)

## 🔄 Mise à jour

Pour réinitialiser la base :

```sql
-- ATTENTION : Supprime toutes les données !
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;

-- Puis réexécuter les scripts d'installation
```
