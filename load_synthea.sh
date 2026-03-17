#!/bin/bash
# ============================================================
#  load_synthea.sh
#  Creates all Synthea healthcare tables in PostgreSQL
#  and bulk loads the CSV files.
#
#  Usage: bash load_synthea.sh
#  Run from the same directory as your docker-compose.yml
# ============================================================

set -e

source .env

CSV_DIR="./backups/synthea_sample_data_csv_latest"
DB="healthcare"
USER="$POSTGRES_USER"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Synthea CSV Loader → PostgreSQL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Helper: load a CSV into a table ──────────────────────
load_csv() {
  local table=$1
  local file="$CSV_DIR/$2"
  echo "  Loading $2 → $table..."
  docker exec -i postgres psql -U "$USER" -d "$DB" \
    -c "\COPY $table FROM STDIN WITH CSV HEADER DELIMITER ','" < "$file"
}

# ── Drop & recreate schema ────────────────────────────────
echo ""
echo "▶ Creating tables..."

docker exec -i postgres psql -U "$USER" -d "$DB" <<'SQL'

-- Drop in reverse dependency order
DROP TABLE IF EXISTS supplies CASCADE;
DROP TABLE IF EXISTS claims_transactions CASCADE;
DROP TABLE IF EXISTS claims CASCADE;
DROP TABLE IF EXISTS payer_transitions_staging CASCADE;
DROP TABLE IF EXISTS payer_transitions CASCADE;
DROP TABLE IF EXISTS procedures CASCADE;
DROP TABLE IF EXISTS observations CASCADE;
DROP TABLE IF EXISTS medications CASCADE;
DROP TABLE IF EXISTS immunizations CASCADE;
DROP TABLE IF EXISTS imaging_studies CASCADE;
DROP TABLE IF EXISTS devices CASCADE;
DROP TABLE IF EXISTS conditions CASCADE;
DROP TABLE IF EXISTS careplans CASCADE;
DROP TABLE IF EXISTS allergies CASCADE;
DROP TABLE IF EXISTS encounters CASCADE;
DROP TABLE IF EXISTS payers CASCADE;
DROP TABLE IF EXISTS providers CASCADE;
DROP TABLE IF EXISTS organizations CASCADE;
DROP TABLE IF EXISTS patients CASCADE;

-- patients
CREATE TABLE patients (
  Id                   UUID PRIMARY KEY,
  BIRTHDATE            DATE,
  DEATHDATE            DATE,
  SSN                  VARCHAR(20),
  DRIVERS              VARCHAR(20),
  PASSPORT             VARCHAR(20),
  PREFIX               VARCHAR(10),
  FIRST                VARCHAR(100),
  MIDDLE               VARCHAR(100),
  LAST                 VARCHAR(100),
  SUFFIX               VARCHAR(10),
  MAIDEN               VARCHAR(100),
  MARITAL              VARCHAR(10),
  RACE                 VARCHAR(50),
  ETHNICITY            VARCHAR(50),
  GENDER               VARCHAR(10),
  BIRTHPLACE           VARCHAR(200),
  ADDRESS              VARCHAR(200),
  CITY                 VARCHAR(100),
  STATE                VARCHAR(50),
  COUNTY               VARCHAR(100),
  FIPS                 VARCHAR(20),
  ZIP                  VARCHAR(20),
  LAT                  NUMERIC,
  LON                  NUMERIC,
  HEALTHCARE_EXPENSES  NUMERIC,
  HEALTHCARE_COVERAGE  NUMERIC,
  INCOME               NUMERIC
);

-- organizations
CREATE TABLE organizations (
  Id          UUID PRIMARY KEY,
  NAME        VARCHAR(200),
  ADDRESS     VARCHAR(200),
  CITY        VARCHAR(100),
  STATE       VARCHAR(50),
  ZIP         VARCHAR(20),
  LAT         NUMERIC,
  LON         NUMERIC,
  PHONE       VARCHAR(30),
  REVENUE     NUMERIC,
  UTILIZATION INTEGER
);

-- providers
CREATE TABLE providers (
  Id             UUID PRIMARY KEY,
  ORGANIZATION   UUID REFERENCES organizations(Id),
  NAME           VARCHAR(200),
  GENDER         VARCHAR(10),
  SPECIALITY     VARCHAR(100),
  ADDRESS        VARCHAR(200),
  CITY           VARCHAR(100),
  STATE          VARCHAR(50),
  ZIP            VARCHAR(20),
  LAT            NUMERIC,
  LON            NUMERIC,
  ENCOUNTERS     INTEGER,
  PROCEDURES     INTEGER
);

-- payers
CREATE TABLE payers (
  Id                        UUID PRIMARY KEY,
  NAME                      VARCHAR(200),
  OWNERSHIP                 VARCHAR(50),
  ADDRESS                   VARCHAR(200),
  CITY                      VARCHAR(100),
  STATE_HEADQUARTERED        VARCHAR(50),
  ZIP                       VARCHAR(20),
  PHONE                     VARCHAR(30),
  AMOUNT_COVERED            NUMERIC,
  AMOUNT_UNCOVERED          NUMERIC,
  REVENUE                   NUMERIC,
  COVERED_ENCOUNTERS        INTEGER,
  UNCOVERED_ENCOUNTERS      INTEGER,
  COVERED_MEDICATIONS       INTEGER,
  UNCOVERED_MEDICATIONS     INTEGER,
  COVERED_PROCEDURES        INTEGER,
  UNCOVERED_PROCEDURES      INTEGER,
  COVERED_IMMUNIZATIONS     INTEGER,
  UNCOVERED_IMMUNIZATIONS   INTEGER,
  UNIQUE_CUSTOMERS          INTEGER,
  QOLS_AVG                  NUMERIC,
  MEMBER_MONTHS             INTEGER
);

-- encounters
CREATE TABLE encounters (
  Id                    UUID PRIMARY KEY,
  START                 TIMESTAMP,
  STOP                  TIMESTAMP,
  PATIENT               UUID REFERENCES patients(Id),
  ORGANIZATION          UUID REFERENCES organizations(Id),
  PROVIDER              UUID REFERENCES providers(Id),
  PAYER                 UUID REFERENCES payers(Id),
  ENCOUNTERCLASS        VARCHAR(50),
  CODE                  VARCHAR(20),
  DESCRIPTION           VARCHAR(300),
  BASE_ENCOUNTER_COST   NUMERIC,
  TOTAL_CLAIM_COST      NUMERIC,
  PAYER_COVERAGE        NUMERIC,
  REASONCODE            VARCHAR(20),
  REASONDESCRIPTION     VARCHAR(300)
);

-- allergies
CREATE TABLE allergies (
  START          DATE,
  STOP           DATE,
  PATIENT        UUID REFERENCES patients(Id),
  ENCOUNTER      UUID REFERENCES encounters(Id),
  CODE           VARCHAR(20),
  SYSTEM         VARCHAR(50),
  DESCRIPTION    VARCHAR(300),
  TYPE           VARCHAR(50),
  CATEGORY       VARCHAR(50),
  REACTION1      VARCHAR(20),
  DESCRIPTION1   VARCHAR(300),
  SEVERITY1      VARCHAR(50),
  REACTION2      VARCHAR(20),
  DESCRIPTION2   VARCHAR(300),
  SEVERITY2      VARCHAR(50)
);

-- careplans
CREATE TABLE careplans (
  Id                UUID,
  START             DATE,
  STOP              DATE,
  PATIENT           UUID REFERENCES patients(Id),
  ENCOUNTER         UUID REFERENCES encounters(Id),
  CODE              VARCHAR(20),
  DESCRIPTION       VARCHAR(300),
  REASONCODE        VARCHAR(20),
  REASONDESCRIPTION VARCHAR(300)
);

-- conditions
CREATE TABLE conditions (
  START          DATE,
  STOP           DATE,
  PATIENT        UUID REFERENCES patients(Id),
  ENCOUNTER      UUID REFERENCES encounters(Id),
  SYSTEM         VARCHAR(50),
  CODE           VARCHAR(20),
  DESCRIPTION    VARCHAR(300)
);

-- devices
CREATE TABLE devices (
  START          TIMESTAMP,
  STOP           TIMESTAMP,
  PATIENT        UUID REFERENCES patients(Id),
  ENCOUNTER      UUID REFERENCES encounters(Id),
  CODE           VARCHAR(20),
  DESCRIPTION    VARCHAR(300),
  UDI            VARCHAR(100)
);

-- imaging_studies
CREATE TABLE imaging_studies (
  Id                   UUID,
  DATE                 TIMESTAMP,
  PATIENT              UUID REFERENCES patients(Id),
  ENCOUNTER            UUID REFERENCES encounters(Id),
  SERIES_UID           VARCHAR(100),
  BODYSITE_CODE        VARCHAR(20),
  BODYSITE_DESCRIPTION VARCHAR(200),
  MODALITY_CODE        VARCHAR(20),
  MODALITY_DESCRIPTION VARCHAR(200),
  INSTANCE_UID         VARCHAR(100),
  SOP_CODE             VARCHAR(100),
  SOP_DESCRIPTION      VARCHAR(200),
  PROCEDURE_CODE       VARCHAR(20)
);

-- immunizations
CREATE TABLE immunizations (
  DATE           TIMESTAMP,
  PATIENT        UUID REFERENCES patients(Id),
  ENCOUNTER      UUID REFERENCES encounters(Id),
  CODE           VARCHAR(20),
  DESCRIPTION    VARCHAR(300),
  BASE_COST      NUMERIC
);

-- medications
CREATE TABLE medications (
  START              TIMESTAMP,
  STOP               TIMESTAMP,
  PATIENT            UUID REFERENCES patients(Id),
  PAYER              UUID REFERENCES payers(Id),
  ENCOUNTER          UUID REFERENCES encounters(Id),
  CODE               VARCHAR(20),
  DESCRIPTION        VARCHAR(300),
  BASE_COST          NUMERIC,
  PAYER_COVERAGE     NUMERIC,
  DISPENSES          INTEGER,
  TOTALCOST          NUMERIC,
  REASONCODE         VARCHAR(20),
  REASONDESCRIPTION  VARCHAR(300)
);

-- observations
CREATE TABLE observations (
  DATE           TIMESTAMP,
  PATIENT        UUID REFERENCES patients(Id),
  ENCOUNTER      UUID REFERENCES encounters(Id),
  CATEGORY       VARCHAR(50),
  CODE           VARCHAR(20),
  DESCRIPTION    VARCHAR(300),
  VALUE          VARCHAR(200),
  UNITS          VARCHAR(50),
  TYPE           VARCHAR(50)
);

-- payer_transitions
-- END_DATE uses a staging table to handle Synthea's out-of-range infinity sentinel value
CREATE TABLE payer_transitions (
  PATIENT           UUID REFERENCES patients(Id),
  MEMBERID          UUID,
  START_DATE        DATE,
  END_DATE          DATE,        -- NULL means "still active"
  PAYER             UUID REFERENCES payers(Id),
  SECONDARY_PAYER   UUID,
  PLAN_OWNERSHIP    VARCHAR(50),
  OWNER_NAME        VARCHAR(200)
);

CREATE TABLE payer_transitions_staging (
  PATIENT           TEXT,
  MEMBERID          TEXT,
  START_DATE        TEXT,
  END_DATE          TEXT,
  PAYER             TEXT,
  SECONDARY_PAYER   TEXT,
  PLAN_OWNERSHIP    TEXT,
  OWNER_NAME        TEXT
);

-- procedures
CREATE TABLE procedures (
  START             TIMESTAMP,
  STOP              TIMESTAMP,
  PATIENT           UUID REFERENCES patients(Id),
  ENCOUNTER         UUID REFERENCES encounters(Id),
  SYSTEM            VARCHAR(50),
  CODE              VARCHAR(20),
  DESCRIPTION       VARCHAR(300),
  BASE_COST         NUMERIC,
  REASONCODE        VARCHAR(20),
  REASONDESCRIPTION VARCHAR(300)
);

-- claims
CREATE TABLE claims (
  Id                           UUID PRIMARY KEY,
  PATIENTID                    UUID REFERENCES patients(Id),
  PROVIDERID                   VARCHAR(50),
  PRIMARYPATIENTINSURANCEID    VARCHAR(50),
  SECONDARYPATIENTINSURANCEID  VARCHAR(50),
  DEPARTMENTID                 VARCHAR(50),
  PATIENTDEPARTMENTID          VARCHAR(50),
  DIAGNOSIS1                   VARCHAR(20),
  DIAGNOSIS2                   VARCHAR(20),
  DIAGNOSIS3                   VARCHAR(20),
  DIAGNOSIS4                   VARCHAR(20),
  DIAGNOSIS5                   VARCHAR(20),
  DIAGNOSIS6                   VARCHAR(20),
  DIAGNOSIS7                   VARCHAR(20),
  DIAGNOSIS8                   VARCHAR(20),
  REFERRINGPROVIDERID          VARCHAR(50),
  APPOINTMENTID                VARCHAR(50),
  CURRENTILLNESSDATE           TIMESTAMP,
  SERVICEDATE                  TIMESTAMP,
  SUPERVISINGPROVIDERID        VARCHAR(50),
  STATUS1                      VARCHAR(50),
  STATUS2                      VARCHAR(50),
  STATUSP                      VARCHAR(50),
  OUTSTANDING1                 NUMERIC,
  OUTSTANDING2                 NUMERIC,
  OUTSTANDINGP                 NUMERIC,
  LASTBILLEDDATE1              TIMESTAMP,
  LASTBILLEDDATE2              TIMESTAMP,
  LASTBILLEDDATEP              TIMESTAMP,
  HEALTHCARECLAIMTYPEID1       INTEGER,
  HEALTHCARECLAIMTYPEID2       INTEGER
);

-- claims_transactions
CREATE TABLE claims_transactions (
  ID                    VARCHAR(50),
  CLAIMID               UUID REFERENCES claims(Id),
  CHARGEID              INTEGER,
  PATIENTID             UUID REFERENCES patients(Id),
  TYPE                  VARCHAR(50),
  AMOUNT                NUMERIC,
  METHOD                VARCHAR(50),
  FROMDATE              TIMESTAMP,
  TODATE                TIMESTAMP,
  PLACEOFSERVICE        VARCHAR(50),
  PROCEDURECODE         VARCHAR(20),
  MODIFIER1             VARCHAR(20),
  MODIFIER2             VARCHAR(20),
  DIAGNOSISREF1         VARCHAR(20),
  DIAGNOSISREF2         VARCHAR(20),
  DIAGNOSISREF3         VARCHAR(20),
  DIAGNOSISREF4         VARCHAR(20),
  UNITS                 INTEGER,
  DEPARTMENTID          VARCHAR(50),
  NOTES                 TEXT,
  UNITAMOUNT            NUMERIC,
  TRANSFEROUTID         VARCHAR(50),
  TRANSFERTYPE          VARCHAR(20),
  PAYMENTS              NUMERIC,
  ADJUSTMENTS           NUMERIC,
  TRANSFERS             NUMERIC,
  OUTSTANDING           NUMERIC,
  APPOINTMENTID         VARCHAR(50),
  LINENOTE              TEXT,
  PATIENTINSURANCEID    VARCHAR(50),
  FEESCHEDULEID         INTEGER,
  PROVIDERID            VARCHAR(50),
  SUPERVISINGPROVIDERID VARCHAR(50)
);

-- supplies
CREATE TABLE supplies (
  DATE           TIMESTAMP,
  PATIENT        UUID REFERENCES patients(Id),
  ENCOUNTER      UUID REFERENCES encounters(Id),
  CODE           VARCHAR(20),
  DESCRIPTION    VARCHAR(300),
  QUANTITY       INTEGER
);

SQL

echo "  ✓ All tables created"

# ── Load CSVs in dependency order ────────────────────────
echo ""
echo "▶ Loading CSV files..."

load_csv "patients"             "patients.csv"
load_csv "organizations"        "organizations.csv"
load_csv "providers"            "providers.csv"
load_csv "payers"               "payers.csv"
load_csv "encounters"           "encounters.csv"
load_csv "allergies"            "allergies.csv"
load_csv "careplans"            "careplans.csv"
load_csv "conditions"           "conditions.csv"
load_csv "devices"              "devices.csv"
load_csv "imaging_studies"      "imaging_studies.csv"
load_csv "immunizations"        "immunizations.csv"
load_csv "medications"          "medications.csv"
load_csv "observations"         "observations.csv"
# Load payer_transitions via staging to handle infinity sentinel date
echo "  Loading payer_transitions.csv → payer_transitions (via staging)..."
docker exec -i postgres psql -U "$USER" -d "$DB" \
  -c "\COPY payer_transitions_staging FROM STDIN WITH CSV HEADER DELIMITER ','" < "$CSV_DIR/payer_transitions.csv"

docker exec -i postgres psql -U "$USER" -d "$DB" -c "
INSERT INTO payer_transitions
  (PATIENT, MEMBERID, START_DATE, END_DATE, PAYER, SECONDARY_PAYER, PLAN_OWNERSHIP, OWNER_NAME)
SELECT
  PATIENT::UUID,
  MEMBERID::UUID,
  START_DATE::DATE,
  CASE
    WHEN END_DATE ~ '^[0-9]{4}-' AND END_DATE::TEXT NOT LIKE '2927%'
         AND LENGTH(SPLIT_PART(END_DATE, '-', 1)) = 4
    THEN END_DATE::DATE
    ELSE NULL
  END,
  PAYER::UUID,
  NULLIF(SECONDARY_PAYER, '')::UUID,
  PLAN_OWNERSHIP,
  OWNER_NAME
FROM payer_transitions_staging;
"
docker exec -i postgres psql -U "$USER" -d "$DB" -c "DROP TABLE payer_transitions_staging;"
load_csv "procedures"           "procedures.csv"
load_csv "claims"               "claims.csv"
load_csv "claims_transactions"  "claims_transactions.csv"
load_csv "supplies"             "supplies.csv"

# ── Row count summary ─────────────────────────────────────
echo ""
echo "▶ Row counts per table:"
docker exec -i postgres psql -U "$USER" -d "$DB" <<'SQL'
SELECT
  tablename,
  (xpath('/row/cnt/text()', query_to_xml(
    format('SELECT COUNT(*) AS cnt FROM %I', tablename), false, true, ''))
  )[1]::text::int AS row_count
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
SQL

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ✅ Synthea data loaded into '$DB' database"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
