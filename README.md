# Multi-Database Docker Stack

A local development environment running four database engines in Docker, pre-loaded with real-world sample datasets. Built for Apple Silicon (ARM64) Macs.

## Stack

| Service | Image | Port |
|---|---|---|
| PostgreSQL 16 | `postgres:16` | `5432` |
| pgAdmin 4 | `dpage/pgadmin4` | `5050` |
| MongoDB 7 | `mongo:7` | `27017` |
| Azure SQL Edge | `mcr.microsoft.com/azure-sql-edge` | `1433` |

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or [OrbStack](https://orbstack.dev))
- Mac with Apple Silicon (M1/M2/M3) or Intel
- Git

---

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME
```

### 2. Configure environment variables

```bash
cp .env.template .env
```

Open `.env` and replace all placeholder values with your own passwords:

```env
POSTGRES_USER=pguser
POSTGRES_PASSWORD=your_password
POSTGRES_DB=mydb

PGADMIN_EMAIL=admin@local.dev
PGADMIN_PASSWORD=your_password

MONGO_ROOT_USER=mongouser
MONGO_ROOT_PASSWORD=your_password
MONGO_DB=mydb

MSSQL_SA_PASSWORD=YourStrong!Passw0rd
```

> ⚠️ The `.env` file is listed in `.gitignore` and will never be committed.

### 3. Set up the backups folder

```
backups/
├── mssql/
│   ├── AdventureWorks2019.bak
│   └── AdventureWorksDW2019.bak
├── synthea_sample_data_csv_latest/
│   ├── patients.csv
│   ├── encounters.csv
│   └── ... (18 CSV files)
└── mongo_sample_dbs/
    ├── sample_airbnb/
    ├── sample_analytics/
    ├── sample_geospatial/
    ├── sample_mflix/
    ├── sample_supplies/
    ├── sample_training/
    └── sample_weatherdata/
```

**Download the sample data:**
- **SQL Server:** [AdventureWorks 2019](https://github.com/Microsoft/sql-server-samples/releases/tag/adventureworks) — download `AdventureWorks2019.bak` and `AdventureWorksDW2019.bak`
- **PostgreSQL:** [Synthea Sample Data (CSV)](https://synthea.mitre.org/downloads)
- **MongoDB:** [Atlas Sample Datasets](https://github.com/neelabalan/mongodb-sample-dataset)

### 4. Start the stack

```bash
docker compose up -d
```

The first run will build the custom SQL Server image (installs `sqlcmd`) — this takes a few minutes but is cached afterwards.

---

## Loading Sample Data

### PostgreSQL — Synthea Healthcare Data

```bash
bash load_synthea.sh
```

> The script automatically creates the `healthcare` database if it doesn't exist — no manual setup needed.

Creates and populates 18 tables in a `healthcare` database:

| Table | Description |
|---|---|
| patients | Synthetic patient demographics |
| encounters | Medical visits |
| conditions | Diagnoses |
| medications | Prescriptions |
| observations | Lab results, vitals |
| procedures | Medical procedures |
| allergies | Allergy records |
| careplans | Care plan details |
| claims | Insurance claims |
| claims_transactions | Claim payment transactions |
| devices | Medical devices |
| imaging_studies | Radiology studies |
| immunizations | Vaccination records |
| organizations | Healthcare organizations |
| payer_transitions | Insurance transitions |
| payers | Insurance payers |
| providers | Healthcare providers |
| supplies | Medical supplies |

### MongoDB — Atlas Sample Datasets

```bash
bash load_mongo.sh
```

Loads 7 databases and 18 collections:

| Database | Collections |
|---|---|
| sample_airbnb | listingsAndReviews |
| sample_analytics | accounts, customers, transactions |
| sample_geospatial | shipwrecks |
| sample_mflix | comments, movies, sessions, theaters, users |
| sample_supplies | sales |
| sample_training | companies, grades, inspections, posts, routes, stories, trips, tweets, zips |
| sample_weatherdata | data |

### SQL Server — AdventureWorks

Run the following after the stack is healthy. Replace `YourPassword` with your `MSSQL_SA_PASSWORD` value:

```bash
# Check logical file names first
source .env && docker exec -it azure_sql_edge sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -No -C \
  -Q "RESTORE FILELISTONLY FROM DISK='/backups/mssql/AdventureWorks2019.bak'"

# Restore AdventureWorks2019
source .env && docker exec -it azure_sql_edge sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -No -C \
  -Q "RESTORE DATABASE [AdventureWorks2019] FROM DISK='/backups/mssql/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2019' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2019_log' TO '/var/opt/mssql/data/AdventureWorks2019_log.ldf', NOUNLOAD, STATS=10"

# Restore AdventureWorksDW2019
source .env && docker exec -it azure_sql_edge sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -No -C \
  -Q "RESTORE DATABASE [AdventureWorksDW2019] FROM DISK='/backups/mssql/AdventureWorksDW2019.bak' WITH MOVE 'AdventureWorksDW2019' TO '/var/opt/mssql/data/AdventureWorksDW2019.mdf', MOVE 'AdventureWorksDW2019_log' TO '/var/opt/mssql/data/AdventureWorksDW2019_log.ldf', NOUNLOAD, STATS=10"
```

> ⚠️ The `-No -C` flags are required because Azure SQL Edge uses a self-signed SSL certificate.

---

## Accessing the Databases

### pgAdmin (PostgreSQL UI)
Open **http://localhost:5050** in your browser.

- **Email:** value of `PGADMIN_EMAIL` in `.env`
- **Password:** value of `PGADMIN_PASSWORD` in `.env`

To connect to PostgreSQL, register a new server with:
- **Host:** `postgres`
- **Port:** `5432`
- **Username:** value of `POSTGRES_USER`
- **Password:** value of `POSTGRES_PASSWORD`

### PostgreSQL (CLI)
```bash
source .env && docker exec -it postgres psql -U $POSTGRES_USER -d healthcare
```

### MongoDB (CLI)
```bash
source .env && docker exec -it mongodb mongosh -u $MONGO_ROOT_USER -p $MONGO_ROOT_PASSWORD --authenticationDatabase admin
```

### SQL Server (CLI)
```bash
source .env && docker exec -it azure_sql_edge sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -No -C
```

---

## Stopping and Starting

```bash
# Stop all containers (data is persisted)
docker compose down

# Start again
docker compose up -d

# Stop and remove all data (destructive!)
docker compose down -v
```

---

## Project Structure

```
.
├── docker-compose.yml        # Main stack definition
├── sqlserver.Dockerfile      # Custom SQL Edge image with sqlcmd
├── load_synthea.sh           # PostgreSQL data loader
├── load_mongo.sh             # MongoDB data loader
├── .env                      # Your credentials (never committed)
├── .env.template             # Credentials template (safe to commit)
├── .gitignore
└── backups/                  # Sample data files (never committed)
    ├── mssql/
    ├── synthea_sample_data_csv_latest/
    └── mongo_sample_dbs/
```

---

## Notes

- **Apple Silicon:** Azure SQL Edge is used instead of standard SQL Server as it is the only ARM64-native Microsoft SQL Server image available. Standard SQL Server `.bak` files from SQL Server 2022+ are not compatible.
- **Persisted storage:** All data is stored in named Docker volumes and survives container restarts. Only `docker compose down -v` will delete it.
- **SSL:** Azure SQL Edge uses a self-signed certificate — always include `-No -C` flags when using `sqlcmd`.
