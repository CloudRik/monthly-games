#!/bin/bash
set -Eeuo pipefail

# Google Skills Boost - Perform Predictive Data Analysis in BigQuery: Challenge Lab (GSP374)
# Run:
# curl -fsSL https://raw.githubusercontent.com/CloudRik/monthly-games/main/Perform-Predictive-Data-Analysis-in-BigQuery-Challenge-Lab/script.sh | bash

trap 'echo; echo "❌ Script stopped at line $LINENO."; exit 1' ERR

echo "=============================================="
echo " BigQuery Predictive Data Analysis Challenge"
echo " Tasks 1-5 Automation"
echo "=============================================="
echo

# IMPORTANT: curl | bash makes stdin the curl pipe, so all interactive input
# is explicitly read from the terminal.
if [[ ! -r /dev/tty ]]; then
  echo "❌ Interactive terminal (/dev/tty) is not available."
  echo "Run this from Google Cloud Shell."
  exit 1
fi

PROJECT_ID="$(gcloud config get-value project 2>/dev/null | tr -d '\r')"
if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
  echo "❌ No active Google Cloud project found."
  echo "Set it with: gcloud config set project YOUR_PROJECT_ID"
  exit 1
fi

gcloud config set project "$PROJECT_ID" >/dev/null
echo "Project: $PROJECT_ID"
echo

# The lab generates these table names per instance and they do not exist
# before Task 1. Therefore they must be entered from the Lab Details panel.
while true; do
  read -r -p "Enter Event Table Name (example: events752): " EVENT_TABLE </dev/tty
  if [[ "$EVENT_TABLE" =~ ^events[[:alnum:]_]+$ ]]; then break; fi
  echo "❌ Invalid event table name. Use the exact name shown in Lab Details."
done

while true; do
  read -r -p "Enter Tags Table Name (example: tags5name): " TAGS_TABLE </dev/tty
  if [[ "$TAGS_TABLE" =~ ^tags[[:alnum:]_]+$ ]]; then break; fi
  echo "❌ Invalid tags table name. Use the exact name shown in Lab Details."
done

# Keep identifiers safe for use in SQL.
if [[ "$EVENT_TABLE" == *.* || "$TAGS_TABLE" == *.* ]]; then
  echo "❌ Enter table names only, not project.dataset.table."
  exit 1
fi

# Current lab's generated model/UDF names follow the Event Table numeric suffix.
SUFFIX="${EVENT_TABLE#events}"
if [[ -z "$SUFFIX" ]]; then
  echo "❌ Could not derive the lab suffix from $EVENT_TABLE."
  exit 1
fi

MODEL="soccer.xg_logistic_reg_model_${SUFFIX}"
DIST_UDF="soccer.GetShotDistanceToGoal${SUFFIX}"
ANGLE_UDF="soccer.GetShotAngleToGoal${SUFFIX}"

echo
echo "Event table : $EVENT_TABLE"
echo "Tags table  : $TAGS_TABLE"
echo "Model       : $MODEL"
echo "Distance UDF: $DIST_UDF"
echo "Angle UDF   : $ANGLE_UDF"
echo

echo "[1/5] Preparing soccer dataset and loading data..."
if bq show --dataset_id="soccer" >/dev/null 2>&1; then
  echo "Dataset soccer already exists; continuing."
else
  bq mk --dataset soccer >/dev/null
  echo "Dataset soccer created."
fi

if bq show "soccer.${EVENT_TABLE}" >/dev/null 2>&1; then
  echo "Table soccer.${EVENT_TABLE} already exists; skipping event load."
else
  bq load \
    --autodetect \
    --source_format=NEWLINE_DELIMITED_JSON \
    "soccer.${EVENT_TABLE}" \
    gs://spls/bq-soccer-analytics/events.json >/dev/null
  echo "Event table loaded."
fi

if bq show "soccer.${TAGS_TABLE}" >/dev/null 2>&1; then
  echo "Table soccer.${TAGS_TABLE} already exists; skipping tags load."
else
  bq load \
    --autodetect \
    --source_format=CSV \
    "soccer.${TAGS_TABLE}" \
    gs://spls/bq-soccer-analytics/tags2name.csv >/dev/null
  echo "Tags table loaded."
fi

echo "✅ Task 1 complete."

echo
echo "[2/5] Calculating penalty-kick success rate..."
bq query --use_legacy_sql=false --quiet "
SELECT
  Players.name AS playerName,
  COUNT(Events.id) AS numPKAtt,
  SUM(IF(101 IN UNNEST(Events.tags.id), 1, 0)) AS numPKGoals,
  SAFE_DIVIDE(
    SUM(IF(101 IN UNNEST(Events.tags.id), 1, 0)),
    COUNT(Events.id)
  ) AS PKSuccessRate
FROM \`${PROJECT_ID}.soccer.${EVENT_TABLE}\` AS Events
JOIN \`${PROJECT_ID}.soccer.players\` AS Players
  ON Events.playerId = Players.wyId
WHERE Events.eventName = 'Free Kick'
  AND Events.subEventName = 'Penalty'
GROUP BY playerName
HAVING numPKAtt >= 5
ORDER BY PKSuccessRate DESC, numPKAtt DESC
" >/dev/null
echo "✅ Task 2 complete."

echo
echo "[3/5] Analyzing shot distance..."
bq query --use_legacy_sql=false --quiet "
WITH shots AS (
  SELECT
    id,
    positions,
    tags,
    101 IN UNNEST(tags.id) AS isGoal
  FROM \`${PROJECT_ID}.soccer.${EVENT_TABLE}\`
  WHERE eventName = 'Shot'
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
" >/dev/null
echo "✅ Task 3 complete."

echo
echo "[4/5] Creating UDFs and training logistic-regression model..."

bq query --use_legacy_sql=false --quiet "
CREATE OR REPLACE FUNCTION \`${PROJECT_ID}.${DIST_UDF}\`(x INT64, y INT64)
RETURNS FLOAT64
AS (
  SQRT(
    POW((120 - x) * 100/100, 2) +
    POW((55 - y) * 65/100, 2)
  )
)
" >/dev/null

bq query --use_legacy_sql=false --quiet "
CREATE OR REPLACE FUNCTION \`${PROJECT_ID}.${ANGLE_UDF}\`(x INT64, y INT64)
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
" >/dev/null

bq query --use_legacy_sql=false --quiet "
CREATE OR REPLACE MODEL \`${PROJECT_ID}.${MODEL}\`
OPTIONS(
  model_type='LOGISTIC_REG',
  labels=['isGoal'],
  input_label_cols=['isGoal']
) AS
WITH Events AS (
  SELECT
    eventName,
    subEventName,
    playerId,
    matchId,
    positions,
    tags,
    101 IN UNNEST(tags.id) AS isGoal
  FROM \`${PROJECT_ID}.soccer.${EVENT_TABLE}\`
  WHERE eventName = 'Shot'
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
JOIN \`${PROJECT_ID}.soccer.matches\` AS Matches
  ON Events.matchId = Matches.wyId
JOIN \`${PROJECT_ID}.soccer.competitions\` AS Competitions
  ON Matches.competitionId = Competitions.wyId
WHERE Competitions.name != 'World Cup'
" >/dev/null

echo "✅ Task 4 complete."

echo
echo "[5/5] Generating World Cup shot predictions..."
bq query --use_legacy_sql=false --quiet "
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
      FROM \`${PROJECT_ID}.soccer.${EVENT_TABLE}\` AS Events
      JOIN \`${PROJECT_ID}.soccer.matches\` AS Matches
        ON Events.matchId = Matches.wyId
      JOIN \`${PROJECT_ID}.soccer.competitions\` AS Competitions
        ON Matches.competitionId = Competitions.wyId
      JOIN \`${PROJECT_ID}.soccer.players\` AS Players
        ON Events.playerId = Players.wyId
      JOIN \`${PROJECT_ID}.soccer.teams\` AS Teams
        ON Events.teamId = Teams.wyId
      WHERE Competitions.name = 'World Cup'
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
" >/dev/null

echo "✅ Task 5 complete."
echo
echo "=============================================="
echo " 🎉 All 5 tasks completed successfully!"
echo "=============================================="
echo
echo "Now open the lab and click Check my progress."
