#!/bin/bash
# ============================================================
#  load_mongo.sh
#  Imports all MongoDB Atlas sample datasets into MongoDB
#
#  Usage: bash load_mongo.sh
#  Run from the same directory as your docker-compose.yml
# ============================================================

set -e

source .env

MONGO_DIR="./backups/mongo_sample_dbs"
CONTAINER="mongodb"
USER="$MONGO_ROOT_USER"
PASS="$MONGO_ROOT_PASSWORD"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " MongoDB Atlas Sample Dataset Loader"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Helper: import a JSON file into a db/collection ──────
import_collection() {
  local db=$1
  local collection=$2
  local file="/backups/mongo_sample_dbs/$db/$3"
  echo "  Importing $3 → $db.$collection..."
  docker exec $CONTAINER mongoimport \
    --username "$USER" \
    --password "$PASS" \
    --authenticationDatabase admin \
    --db "$db" \
    --collection "$collection" \
    --file "$file" 
}

# ── sample_airbnb ─────────────────────────────────────────
echo ""
echo "▶ sample_airbnb"
import_collection "sample_airbnb" "listingsAndReviews" "listingsAndReviews.json"

# ── sample_analytics ─────────────────────────────────────
echo ""
echo "▶ sample_analytics"
import_collection "sample_analytics" "accounts"     "accounts.json"
import_collection "sample_analytics" "customers"    "customers.json"
import_collection "sample_analytics" "transactions" "transactions.json"

# ── sample_geospatial ─────────────────────────────────────
echo ""
echo "▶ sample_geospatial"
import_collection "sample_geospatial" "shipwrecks" "shipwrecks.json"

# ── sample_mflix ──────────────────────────────────────────
echo ""
echo "▶ sample_mflix"
import_collection "sample_mflix" "comments" "comments.json"
import_collection "sample_mflix" "movies"   "movies.json"
import_collection "sample_mflix" "sessions" "sessions.json"
import_collection "sample_mflix" "theaters" "theaters.json"
import_collection "sample_mflix" "users"    "users.json"

# ── sample_supplies ───────────────────────────────────────
echo ""
echo "▶ sample_supplies"
import_collection "sample_supplies" "sales" "sales.json"

# ── sample_training ───────────────────────────────────────
echo ""
echo "▶ sample_training"
import_collection "sample_training" "companies"   "companies.json"
import_collection "sample_training" "grades"      "grades.json"
import_collection "sample_training" "inspections" "inspections.json"
import_collection "sample_training" "posts"       "posts.json"
import_collection "sample_training" "routes"      "routes.json"
import_collection "sample_training" "stories"     "stories.json"
import_collection "sample_training" "trips"       "trips.json"
import_collection "sample_training" "tweets"      "tweets.json"
import_collection "sample_training" "zips"        "zips.json"

# ── sample_weatherdata ────────────────────────────────────
echo ""
echo "▶ sample_weatherdata"
import_collection "sample_weatherdata" "data" "data.json"

# ── Summary ───────────────────────────────────────────────
echo ""
echo "▶ Collection counts per database:"
docker exec -i $CONTAINER mongosh \
  --username "$USER" \
  --password "$PASS" \
  --authenticationDatabase admin \
  --quiet \
  --eval "
    const dbs = [
      'sample_airbnb',
      'sample_analytics',
      'sample_geospatial',
      'sample_mflix',
      'sample_supplies',
      'sample_training',
      'sample_weatherdata'
    ];
    for (const dbName of dbs) {
      const d = db.getSiblingDB(dbName);
      const cols = d.getCollectionNames();
      print('');
      print('  ' + dbName);
      for (const col of cols) {
        const count = d.getCollection(col).countDocuments();
        print('    ' + col + ': ' + count + ' documents');
      }
    }
  "

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ✅ All datasets loaded into MongoDB"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
