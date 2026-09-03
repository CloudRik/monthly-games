#!/bin/bash
set -Eeuo pipefail

# Google Skills / BigQuery Challenge Lab automation
# Performs Tasks 1-5 for "Perform Predictive Data Analysis in BigQuery".
# Dynamic values are collected from the current Cloud Skills Boost lab.
#
# Fixed lab resources:
#   Dataset: soccer
#   Event source: gs://spls/bq-soccer-analytics/events.json
#   Tags source:  gs://spls/bq-soccer-analytics/tags2name.csv
#   Goal tag: 101
#   Goal midpoint: (120,55)
#   Field dimensions: 100x65
#   Goal opening: 7.32

trap 'echo; echo "❌ Script stopped at line $LINENO. Check the message above."; exit 1' ERR

command -v gcloud >/dev/null 2>&1 || { echo "❌ gcloud is not installed."; exit 1; }
command -v bq >/dev/null 2>&1 || { echo "❌ bq is not installed."; exit 1; }

echo "=============================================="
echo " Google Skills BigQuery Challenge Automation"
echo " Tasks 1-5"
echo "=============================================="
echo

# ---------- Project ----------
CURRENT_PROJECT="$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')"
if [[ -n "$CURRENT_PROJECT" && "$CURRENT_PROJECT" != "(unset)" ]]; then
  read -r -p "Project ID [$CURRENT_PROJECT]: " PROJECT_ID
  PROJECT_ID="${PROJECT_ID:-$CURRENT_PROJECT}"
else
  read -r -p "Enter Project ID: " PROJECT_ID
fi

if [[ ! "$PROJECT_ID" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
  echo "❌ Invalid Google Cloud Project ID: $PROJECT_ID"
  exit 1
fi

gcloud config set project "$PROJECT_ID" >/dev/null
echo "✅ Project: $PROJECT_ID"

# ---------- Dataset ----------
DATASET="soccer"
if bq --project_id="$PROJECT_ID" show "$PROJECT_ID:$DATASET" >/dev/null 2>&1; then
  echo "✅ Dataset $DATASET already exists; continuing."
else
  echo "→ Creating dataset $DATASET..."
  bq --project_id="$PROJECT_ID" mk --dataset "$PROJECT_ID:$DATASET" >/dev/null
  echo "✅ Dataset created."
fi

# ---------- Detect / ask dynamic table names ----------
mapfile -t EVENT_TABLES < <(
  bq --project_id="$PROJECT_ID" ls --format=prettyjson "$DATASET" 2>/dev/null |
  python3 -c '
import json,sys
try:
    data=json.load(sys.stdin)
except Exception:
    sys.exit(0)
for x in data:
    ref=x.get("tableReference",{})
    if ref.get("tableId","").startswith("events") and x.get("type","") in ("TABLE","VIEW","EXTERNAL"):
        print(ref.get("tableId"))
'
)

mapfile -t TAG_TABLES < <(
  bq --project_id="$PROJECT_ID" ls --format=prettyjson "$DATASET" 2>/dev/null |
  python3 -c '
import json,sys
try:
    data=json.load(sys.stdin)
except Exception:
    sys.exit(0)
for x in data:
    ref=x.get("tableReference",{})
    if ref.get("tableId","").startswith("tags") and x.get("type","") in ("TABLE","VIEW","EXTERNAL"):
        print(ref.get("tableId"))
'
)

DEFAULT_EVENT="${EVENT_TABLES[0]:-}"
DEFAULT_TAG="${TAG_TABLES[0]:-}"

if [[ -n "$DEFAULT_EVENT" ]]; then
  read -r -p "Event table name [$DEFAULT_EVENT]: " EVENT_TABLE
  EVENT_TABLE="${EVENT_TABLE:-$DEFAULT_EVENT}"
else
  read -r -p "Enter Event table name (example: events752): " EVENT_TABLE
fi

if [[ -n "$DEFAULT_TAG" ]]; then
  read -r -p "Tags table name [$DEFAULT_TAG]: " TAGS_TABLE
  TAGS_TABLE="${TAGS_TABLE:-$DEFAULT_TAG}"
else
  read -r -p "Enter Tags table name (example: tags5name): " TAGS_TABLE
fi

# BigQuery identifiers are intentionally restricted to simple lab resource names.
if [[ ! "$EVENT_TABLE" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "❌ Invalid event table identifier: $EVENT_TABLE"
  exit 1
fi
if [[ ! "$TAGS_TABLE" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "❌ Invalid tags table identifier: $TAGS_TABLE"
  exit 1
fi

# Lab instances use a numeric suffix shared by the event table, UDFs and model.
if [[ "$EVENT_TABLE" =~ ^events([0-9]+)$ ]]; then
  SUFFIX="${BASH_REMATCH[1]}"
else
  read -r -p "Enter the numeric lab suffix used by the UDF/model names: " SUFFIX
  [[ "$SUFFIX" =~ ^[0-9]+$ ]] || { echo "❌ Suffix must be numeric."; exit 1; }
fi

DIST_FUNC="GetShotDistanceToGoal${SUFFIX}"
ANGLE_FUNC="GetShotAngleToGoal${SUFFIX}"
MODEL="xg_logistic_reg_model_${SUFFIX}"

EVENT_FQN="${PROJECT_ID}.${DATASET}.${EVENT_TABLE}"
TAGS_FQN="${PROJECT_ID}.${DATASET}.${TAGS_TABLE}"
DIST_FUNC_FQN="${PROJECT_ID}.${DATASET}.${DIST_FUNC}"
ANGLE_FUNC_FQN="${PROJECT_ID}.${DATASET}.${ANGLE_FUNC}"
MODEL_FQN="${PROJECT_ID}.${DATASET}.${MODEL}"

echo
echo "----------------------------------------------"
echo "Resolved lab resources"
echo "----------------------------------------------"
echo "Project       : $PROJECT_ID"
echo "Dataset       : $DATASET"
echo "Event table   : $EVENT_TABLE"
echo "Tags table    : $TAGS_TABLE"
echo "Suffix        : $SUFFIX"
echo "Distance UDF  : $DIST_FUNC"
echo "Angle UDF     : $ANGLE_FUNC"
echo "Model         : $MODEL"
echo "----------------------------------------------"
echo

read -r -p "Press Enter to start automation, or Ctrl+C to cancel..."

# ---------- Task 1 ----------
echo
echo "▶ Task 1: Data ingestion"

if bq --project_id="$PROJECT_ID" show "$EVENT_FQN" >/dev/null 2>&1; then
  echo "ℹ️  $EVENT_TABLE already exists; skipping event reload to avoid duplicate rows."
else
  bq --project_id="$PROJECT_ID" load \
    --autodetect \
    --source_format=NEWLINE_DELIMITED_JSON \
    "$EVENT_FQN" \
    gs://spls/bq-soccer-analytics/events.json
  echo "✅ Event table loaded."
fi

if bq --project_id="$PROJECT_ID" show "$TAGS_FQN" >/dev/null 2>&1; then
  echo "ℹ️  $TAGS_TABLE already exists; skipping tags reload to avoid duplicate rows."
else
  bq --project_id="$PROJECT_ID" load \
    --autodetect \
    --source_format=CSV \
    "$TAGS_FQN" \
    gs://spls/bq-soccer-analytics/tags2name.csv
  echo "✅ Tags table loaded."
fi

bq --project_id="$PROJECT_ID" show "$EVENT_FQN" >/dev/null
bq --project_id="$PROJECT_ID" show "$TAGS_FQN" >/dev/null
echo "✅ Task 1 resources verified."

# ---------- Task 2 ----------
echo
echo "▶ Task 2: Penalty-kick success rate"

bq --project_id="$PROJECT_ID" query --use_legacy_sql=false '
SELECT
  playerId,
  (Players.firstName || " " || Players.lastName) AS playerName,
  COUNT(id) AS numPKAtt,
  SUM(IF(101 IN UNNEST(tags.id), 1, 0)) AS numPKGoals,
  SAFE_DIVIDE(
    SUM(IF(101 IN UNNEST(tags.id), 1, 0)),
    COUNT(id)
  ) AS PKSuccessRate
FROM `'"$EVENT_FQN"'` AS Events
LEFT JOIN `'"$PROJECT_ID.$DATASET"'.players` AS Players
  ON Events.playerId = Players.wyId
WHERE eventName = "Free Kick"
  AND subEventName = "Penalty"
GROUP BY playerId, playerName
HAVING numPKAtt >= 5
ORDER BY PKSuccessRate DESC, numPKAtt DESC
' >/dev/null

echo "✅ Task 2 query completed."

# ---------- Task 3 ----------
echo
echo "▶ Task 3: Shot-distance analysis"

bq --project_id="$PROJECT_ID" query --use_legacy_sql=false '
WITH Shots AS (
  SELECT
    *,
    101 IN UNNEST(tags.id) AS isGoal,
    SQRT(
      POW((120 - positions[ORDINAL(1)].x) * 100/100, 2) +
      POW((55 - positions[ORDINAL(1)].y) * 65/100, 2)
    ) AS shotDistance
  FROM `'"$EVENT_FQN"'`
  WHERE
    eventName = "Shot"
    OR (
      eventName = "Free Kick"
      AND subEventName IN ("Free kick shot", "Penalty")
    )
)
SELECT
  ROUND(shotDistance, 0) AS ShotDistRound0,
  COUNT(*) AS numShots,
  SUM(IF(isGoal, 1, 0)) AS numGoals,
  AVG(IF(isGoal, 1, 0)) AS goalPct
FROM Shots
WHERE shotDistance < 50
GROUP BY ShotDistRound0
ORDER BY ShotDistRound0
' >/dev/null

echo "✅ Task 3 query completed."

# ---------- Task 4 ----------
echo
echo "▶ Task 4: UDFs + BigQuery ML logistic regression model"

bq --project_id="$PROJECT_ID" query --use_legacy_sql=false "
CREATE OR REPLACE FUNCTION \`$DIST_FUNC_FQN\`(x INT64, y INT64)
RETURNS FLOAT64
AS (
  SQRT(
    POW((120 - x) * 100/100, 2) +
    POW((55 - y) * 65/100, 2)
  )
)
"

bq --project_id="$PROJECT_ID" query --use_legacy_sql=false "
CREATE OR REPLACE FUNCTION \`$ANGLE_FUNC_FQN\`(x INT64, y INT64)
RETURNS FLOAT64
AS (
  SAFE.ACOS(
    SAFE_DIVIDE(
      (
        (POW(100 - (x * 100/100), 2) +
         POW(32.5 + (7.32/2) - (y * 65/100), 2))
        +
        (POW(100 - (x * 100/100), 2) +
         POW(32.5 - (7.32/2) - (y * 65/100), 2))
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

echo "✅ Distance and angle UDFs created."

# World Cup is excluded from model fitting and included for prediction.
bq --project_id="$PROJECT_ID" query --use_legacy_sql=false "
CREATE OR REPLACE MODEL \`$MODEL_FQN\`
OPTIONS(
  model_type = 'LOGISTIC_REG',
  input_label_cols = ['isGoal']
) AS
SELECT
  Events.subEventName AS shotType,
  (101 IN UNNEST(Events.tags.id)) AS isGoal,
  \`$DIST_FUNC_FQN\`(
    Events.positions[ORDINAL(1)].x,
    Events.positions[ORDINAL(1)].y
  ) AS shotDistance,
  \`$ANGLE_FUNC_FQN\`(
    Events.positions[ORDINAL(1)].x,
    Events.positions[ORDINAL(1)].y
  ) AS shotAngle
FROM \`$EVENT_FQN\` AS Events
LEFT JOIN \`$PROJECT_ID.$DATASET.matches\` AS Matches
  ON Events.matchId = Matches.wyId
LEFT JOIN \`$PROJECT_ID.$DATASET.competitions\` AS Competitions
  ON Matches.competitionId = Competitions.wyId
WHERE
  Competitions.name != 'World Cup'
  AND (
    eventName = 'Shot'
    OR (
      eventName = 'Free Kick'
      AND subEventName IN ('Free kick shot', 'Penalty')
    )
  )
"

echo "✅ Logistic regression model created/training completed."

# ---------- Task 5 ----------
echo
echo "▶ Task 5: World Cup predictions"

bq --project_id="$PROJECT_ID" query --use_legacy_sql=false "
SELECT
  predicted_isGoal_probs[ORDINAL(1)].prob AS predictedGoalProb,
  *
FROM
  ML.PREDICT(
    MODEL \`$MODEL_FQN\`,
    (
      SELECT
        Events.playerId,
        (Players.firstName || ' ' || Players.lastName) AS playerName,
        Teams.name AS teamName,
        CAST(Matches.dateutc AS DATE) AS matchDate,
        Matches.label AS match,
        CASE
          WHEN Events.matchPeriod = '1H' THEN 0
          WHEN Events.matchPeriod = '2H' THEN 45
          WHEN Events.matchPeriod = 'E1' THEN 90
          WHEN Events.matchPeriod = 'E2' THEN 105
          WHEN Events.matchPeriod = 'P' THEN 120
          ELSE 0
        END
        + CAST(CEIL(Events.eventSec / 60) AS INT64) AS matchMinute,
        Events.subEventName AS shotType,
        (101 IN UNNEST(Events.tags.id)) AS isGoal,
        \`$DIST_FUNC_FQN\`(
          Events.positions[ORDINAL(1)].x,
          Events.positions[ORDINAL(1)].y
        ) AS shotDistance,
        \`$ANGLE_FUNC_FQN\`(
          Events.positions[ORDINAL(1)].x,
          Events.positions[ORDINAL(1)].y
        ) AS shotAngle
      FROM \`$EVENT_FQN\` AS Events
      LEFT JOIN \`$PROJECT_ID.$DATASET.matches\` AS Matches
        ON Events.matchId = Matches.wyId
      LEFT JOIN \`$PROJECT_ID.$DATASET.competitions\` AS Competitions
        ON Matches.competitionId = Competitions.wyId
      LEFT JOIN \`$PROJECT_ID.$DATASET.players\` AS Players
        ON Events.playerId = Players.wyId
      LEFT JOIN \`$PROJECT_ID.$DATASET.teams\` AS Teams
        ON Events.teamId = Teams.wyId
      WHERE
        Competitions.name = 'World Cup'
        AND (
          eventName = 'Shot'
          OR (
            eventName = 'Free Kick'
            AND subEventName IN ('Free kick shot', 'Penalty')
          )
        )
    )
  )
ORDER BY predictedGoalProb DESC
" >/dev/null

echo
echo "=============================================="
echo " 🎉 Automation completed successfully!"
echo "=============================================="
echo "Project       : $PROJECT_ID"
echo "Event table   : $EVENT_TABLE"
echo "Tags table    : $TAGS_TABLE"
echo "Model         : $MODEL"
echo
echo "Now open the Skills Lab and click 'Check my progress' for Tasks 1-5."
