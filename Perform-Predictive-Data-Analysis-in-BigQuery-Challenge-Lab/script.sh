#!/bin/bash
set -Eeuo pipefail

# ============================================================
# Google Skills Boost
# Perform Predictive Data Analysis in BigQuery: Challenge Lab
# GSP374
#
# Run from Cloud Shell:
# curl -fsSL https://raw.githubusercontent.com/CloudRik/monthly-games/main/Perform-Predictive-Data-Analysis-in-BigQuery-Challenge-Lab/script.sh | bash
#
# The script asks ONLY for the lab-specific names shown in
# Lab Details. Everything else is fixed from the current lab.
# ============================================================

trap 'echo; echo "❌ Script stopped at line $LINENO."; echo "The BigQuery error is shown above."; exit 1' ERR

echo "============================================================"
echo " BigQuery Predictive Data Analysis - Challenge Lab"
echo " Tasks 1-5 Automation"
echo "============================================================"
echo

# curl | bash uses the pipe as stdin. Read interactive answers
# directly from the terminal.
if [[ ! -r /dev/tty ]]; then
    echo "❌ Terminal input is unavailable. Run this in Google Cloud Shell."
    exit 1
fi

# ------------------------------------------------------------
# Project
# ------------------------------------------------------------
PROJECT_ID="$(gcloud config get-value project 2>/dev/null | tr -d '\r')"

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
    echo "❌ No active Google Cloud project found."
    exit 1
fi

gcloud config set project "$PROJECT_ID" >/dev/null

echo "Project: $PROJECT_ID"
echo

# ------------------------------------------------------------
# LAB-SPECIFIC VALUES
# These are the values the user sees in Lab Details.
# Ask for all dynamic resource names explicitly instead of
# guessing/deriving them.
# ------------------------------------------------------------

read -r -p "Enter Event Table Name (e.g. events479): " EVENT_TABLE </dev/tty
read -r -p "Enter Tags Table Name (e.g. tags3name): " TAGS_TABLE </dev/tty
read -r -p "Enter Model Name (e.g. xg_logistic_reg_model_479): " MODEL_NAME </dev/tty
read -r -p "Enter Distance UDF Name (e.g. GetShotDistanceToGoal479): " DIST_UDF_NAME </dev/tty
read -r -p "Enter Angle UDF Name (e.g. GetShotAngleToGoal479): " ANGLE_UDF_NAME </dev/tty

# Basic identifier validation.
validate_identifier() {
    local value="$1"
    local label="$2"

    if [[ ! "$value" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        echo "❌ Invalid $label: $value"
        echo "Use the exact resource NAME only, without project or dataset."
        exit 1
    fi
}

validate_identifier "$EVENT_TABLE" "event table name"
validate_identifier "$TAGS_TABLE" "tags table name"
validate_identifier "$MODEL_NAME" "model name"
validate_identifier "$DIST_UDF_NAME" "distance UDF name"
validate_identifier "$ANGLE_UDF_NAME" "angle UDF name"

DATASET="soccer"
MODEL="${DATASET}.${MODEL_NAME}"
DIST_UDF="${DATASET}.${DIST_UDF_NAME}"
ANGLE_UDF="${DATASET}.${ANGLE_UDF_NAME}"

echo
echo "------------------------------------------------------------"
echo "Lab configuration"
echo "------------------------------------------------------------"
echo "Event table : $DATASET.$EVENT_TABLE"
echo "Tags table  : $DATASET.$TAGS_TABLE"
echo "Model       : $MODEL"
echo "Distance UDF: $DIST_UDF"
echo "Angle UDF   : $ANGLE_UDF"
echo "------------------------------------------------------------"
echo

# ============================================================
# TASK 1 — DATA INGESTION
# ============================================================
echo "[1/5] Task 1 - Loading soccer data..."

if bq show --dataset_id="$DATASET" >/dev/null 2>&1; then
    echo "Dataset $DATASET already exists; continuing."
else
    bq mk "$DATASET"
fi

if bq show "$DATASET.$EVENT_TABLE" >/dev/null 2>&1; then
    echo "Event table $DATASET.$EVENT_TABLE already exists; skipping load."
else
    bq load \
        --autodetect \
        --source_format=NEWLINE_DELIMITED_JSON \
        "$DATASET.$EVENT_TABLE" \
        gs://spls/bq-soccer-analytics/events.json
fi

if bq show "$DATASET.$TAGS_TABLE" >/dev/null 2>&1; then
    echo "Tags table $DATASET.$TAGS_TABLE already exists; skipping load."
else
    bq load \
        --autodetect \
        --source_format=CSV \
        "$DATASET.$TAGS_TABLE" \
        gs://spls/bq-soccer-analytics/tags2name.csv
fi

echo "✅ Task 1 complete."
echo

# ============================================================
# TASK 2 — PENALTY KICK SUCCESS RATE
# ============================================================
echo "[2/5] Task 2 - Calculating penalty-kick success rate..."

bq query --use_legacy_sql=false "
SELECT
  playerId,
  (Players.firstName || ' ' || Players.lastName) AS playerName,
  COUNT(id) AS numPKAtt,
  SUM(IF(101 IN UNNEST(tags.id), 1, 0)) AS numPKGoals,
  SAFE_DIVIDE(
    SUM(IF(101 IN UNNEST(tags.id), 1, 0)),
    COUNT(id)
  ) AS PKSuccessRate
FROM
  \`${PROJECT_ID}.${DATASET}.${EVENT_TABLE}\` AS Events
LEFT JOIN
  \`${PROJECT_ID}.${DATASET}.players\` AS Players
ON
  Events.playerId = Players.wyId
WHERE
  eventName = 'Free Kick'
  AND subEventName = 'Penalty'
GROUP BY
  playerId,
  playerName
HAVING
  numPKAtt >= 5
ORDER BY
  PKSuccessRate DESC,
  numPKAtt DESC
"

echo "✅ Task 2 complete."
echo

# ============================================================
# TASK 3 — SHOT DISTANCE ANALYSIS
# Current lab values:
# Goal midpoint = (120,55)
# Field = 100 x 65
# Goal tag = 101
# Distance < 50
# ============================================================
echo "[3/5] Task 3 - Analyzing shot distance..."

bq query --use_legacy_sql=false "
WITH shots AS (
  SELECT
    id,
    positions,
    tags,
    101 IN UNNEST(tags.id) AS isGoal
  FROM
    \`${PROJECT_ID}.${DATASET}.${EVENT_TABLE}\`
  WHERE
    eventName = 'Shot'
    OR (
      eventName = 'Free Kick'
      AND subEventName IN ('Free kick shot', 'Penalty')
    )
),
shot_distances AS (
  SELECT
    *,
    SQRT(
      POW((120 - positions[ORDINAL(1)].x) * 100/100, 2) +
      POW((55 - positions[ORDINAL(1)].y) * 65/100, 2)
    ) AS shotDistance
  FROM shots
)
SELECT
  ROUND(shotDistance, 0) AS ShotDistRound0,
  COUNT(*) AS numShots,
  SUM(IF(isGoal, 1, 0)) AS numGoals,
  AVG(IF(isGoal, 1, 0)) AS goalPct
FROM shot_distances
WHERE shotDistance < 50
GROUP BY ShotDistRound0
ORDER BY ShotDistRound0
"

echo "✅ Task 3 complete."
echo

# ============================================================
# TASK 4 — UDFs + LOGISTIC REGRESSION MODEL
# ============================================================
echo "[4/5] Task 4 - Creating UDFs and training model..."

echo "Creating distance UDF..."
bq query --use_legacy_sql=false "
CREATE OR REPLACE FUNCTION
  \`${PROJECT_ID}.${DIST_UDF}\`(x INT64, y INT64)
RETURNS FLOAT64
AS (
  SQRT(
    POW((120 - x) * 100/100, 2) +
    POW((55 - y) * 65/100, 2)
  )
)
"

echo "Creating angle UDF..."
bq query --use_legacy_sql=false "
CREATE OR REPLACE FUNCTION
  \`${PROJECT_ID}.${ANGLE_UDF}\`(x INT64, y INT64)
RETURNS FLOAT64
AS (
  SAFE.ACOS(
    SAFE_DIVIDE(
      (
        (
          POW(100 - (x * 100/100), 2) +
          POW(32.5 + (7.32/2) - (y * 65/100), 2)
        )
        +
        (
          POW(100 - (x * 100/100), 2) +
          POW(32.5 - (7.32/2) - (y * 65/100), 2)
        )
        -
        POW(7.32, 2)
      ),
      (
        2 *
        SQRT(
          POW(100 - (x * 100/100), 2) +
          POW(32.5 + 7.32/2 - (y * 65/100), 2)
        ) *
        SQRT(
          POW(100 - (x * 100/100), 2) +
          POW(32.5 - 7.32/2 - (y * 65/100), 2)
        )
      )
    )
  ) * 180 / ACOS(-1)
)
"

echo "Training logistic regression model..."
bq query --use_legacy_sql=false "
CREATE OR REPLACE MODEL
  \`${PROJECT_ID}.${MODEL}\`
OPTIONS(
  model_type = 'LOGISTIC_REG',
  labels = ['isGoal'],
  input_label_cols = ['isGoal']
)
AS
WITH Events AS (
  SELECT
    eventName,
    subEventName,
    playerId,
    matchId,
    positions,
    tags,
    101 IN UNNEST(tags.id) AS isGoal
  FROM
    \`${PROJECT_ID}.${DATASET}.${EVENT_TABLE}\`
  WHERE
    eventName = 'Shot'
    OR (
      eventName = 'Free Kick'
      AND subEventName IN ('Free kick shot', 'Penalty')
    )
)
SELECT
  subEventName AS shotType,
  isGoal,
  \`${PROJECT_ID}.${DIST_UDF}\`(
    positions[ORDINAL(1)].x,
    positions[ORDINAL(1)].y
  ) AS shotDistance,
  \`${PROJECT_ID}.${ANGLE_UDF}\`(
    positions[ORDINAL(1)].x,
    positions[ORDINAL(1)].y
  ) AS shotAngle
FROM Events
JOIN
  \`${PROJECT_ID}.${DATASET}.matches\` AS Matches
ON
  Events.matchId = Matches.wyId
JOIN
  \`${PROJECT_ID}.${DATASET}.competitions\` AS Competitions
ON
  Matches.competitionId = Competitions.wyId
WHERE
  Competitions.name != 'World Cup'
"

echo "✅ Task 4 complete."
echo

# ============================================================
# TASK 5 — WORLD CUP PREDICTIONS
# ============================================================
echo "[5/5] Task 5 - Generating World Cup predictions..."

bq query --use_legacy_sql=false "
WITH predictions AS (
  SELECT *
  FROM ML.PREDICT(
    MODEL \`${PROJECT_ID}.${MODEL}\`,
    (
      SELECT
        Events.playerId,
        Players.name AS playerName,
        Teams.name AS teamName,
        Matches.date AS matchDate,
        Matches.wyId AS matchId,
        Events.matchPeriod,
        Events.eventSec,
        Events.subEventName AS shotType,
        101 IN UNNEST(Events.tags.id) AS isGoal,
        \`${PROJECT_ID}.${DIST_UDF}\`(
          Events.positions[ORDINAL(1)].x,
          Events.positions[ORDINAL(1)].y
        ) AS shotDistance,
        \`${PROJECT_ID}.${ANGLE_UDF}\`(
          Events.positions[ORDINAL(1)].x,
          Events.positions[ORDINAL(1)].y
        ) AS shotAngle
      FROM
        \`${PROJECT_ID}.${DATASET}.${EVENT_TABLE}\` AS Events
      JOIN
        \`${PROJECT_ID}.${DATASET}.matches\` AS Matches
      ON
        Events.matchId = Matches.wyId
      JOIN
        \`${PROJECT_ID}.${DATASET}.competitions\` AS Competitions
      ON
        Matches.competitionId = Competitions.wyId
      JOIN
        \`${PROJECT_ID}.${DATASET}.players\` AS Players
      ON
        Events.playerId = Players.wyId
      JOIN
        \`${PROJECT_ID}.${DATASET}.teams\` AS Teams
      ON
        Events.teamId = Teams.wyId
      WHERE
        Competitions.name = 'World Cup'
        AND (
          Events.eventName = 'Shot'
          OR (
            Events.eventName = 'Free Kick'
            AND Events.subEventName IN ('Free kick shot', 'Penalty')
          )
        )
    )
  )
)
SELECT
  playerId,
  playerName,
  teamName,
  matchDate,
  matchId,
  matchPeriod,
  eventSec,
  shotType,
  isGoal,
  shotDistance,
  shotAngle,
  predicted_isGoal_probs[ORDINAL(1)].prob AS predictedGoalProb
FROM predictions
ORDER BY predictedGoalProb DESC
"

echo "✅ Task 5 complete."
echo
echo "============================================================"
echo "🎉 ALL 5 TASKS COMPLETED"
echo "============================================================"
echo
echo "Now click 'Check my progress' in the lab."
