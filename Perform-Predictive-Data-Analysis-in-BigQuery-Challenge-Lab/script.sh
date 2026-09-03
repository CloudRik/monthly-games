#!/bin/bash

# Enable immediate exit on error
set -e

# Fetch Environment Variables
export PROJECT_ID=$(gcloud config get-value project)

# Extract Dynamic Table and Function Names automatically from environment or defaults
export EVENT_NAME=$(bq ls --format=json $PROJECT_ID:soccer 2>/dev/null | grep -o '"tableId":"events[^"]*"' | head -n 1 | cut -d'"' -f4 || echo "events")
export TAG_TABLE=$(bq ls --format=json $PROJECT_ID:soccer 2>/dev/null | grep -o '"tableId":"tags[^"]*"' | head -n 1 | cut -d'"' -f4 || echo "tags2name")

# Identify Function Names based on project tables
DIST_FUNC_NAME=$(bq ls --format=json $PROJECT_ID:soccer 2>/dev/null | grep -o '"routineId":"GetShotDistanceToGoa[^"]*"' | head -n 1 | cut -d'"' -f4 || echo "GetShotDistanceToGoal")
ANGLE_FUNC_NAME=$(bq ls --format=json $PROJECT_ID:soccer 2>/dev/null | grep -o '"routineId":"GetShotAngleToGoa[^"]*"' | head -n 1 | cut -d'"' -f4 || echo "GetShotAngleToGoal")

export MODEL_NAME="soccer.xg_logistic_reg_model"

echo "Detected Environment Configuration:"
echo "Project ID: $PROJECT_ID"
echo "Event Table: $EVENT_NAME"
echo "Tag Table: $TAG_TABLE"

# Ensure BigQuery Dataset Exists
bq mk --dataset --location=US $PROJECT_ID:soccer 2>/dev/null || true

# Task 1: Data Ingestion
echo "Executing Task 1: Ingesting Soccer Data into BigQuery..."
bq load --source_format=NEWLINE_DELIMITED_JSON --autodetect $PROJECT_ID:soccer.$EVENT_NAME gs://spls/bq-soccer-analytics/events.json
bq load --source_format=CSV --autodetect $PROJECT_ID:soccer.$TAG_TABLE gs://spls/bq-soccer-analytics/tags2name.csv
bq load --autodetect --source_format=NEWLINE_DELIMITED_JSON $PROJECT_ID:soccer.competitions gs://spls/bq-soccer-analytics/competitions.json
bq load --autodetect --source_format=NEWLINE_DELIMITED_JSON $PROJECT_ID:soccer.matches gs://spls/bq-soccer-analytics/matches.json
bq load --autodetect --source_format=NEWLINE_DELIMITED_JSON $PROJECT_ID:soccer.teams gs://spls/bq-soccer-analytics/teams.json
bq load --autodetect --source_format=NEWLINE_DELIMITED_JSON $PROJECT_ID:soccer.players gs://spls/bq-soccer-analytics/players.json

# Task 2: Analyze Penalty Kicks
echo "Executing Task 2: Analyzing Penalty Kick Success Rate..."
bq query --use_legacy_sql=false \
"
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
  \`$PROJECT_ID.soccer.$EVENT_NAME\` Events
LEFT JOIN
  \`$PROJECT_ID.soccer.players\` Players ON Events.playerId = Players.wyId
WHERE
  eventName = 'Free Kick' AND subEventName = 'Penalty'
GROUP BY
  playerId, playerName
HAVING
  numPkAtt >= 5
ORDER BY
  PKSuccessRate DESC, numPKAtt DESC
"

# Task 3: Gain Insight by Distance Analysis
echo "Executing Task 3: Calculating Shot Distances and Goal Percentages..."
bq query --use_legacy_sql=false \
"
WITH Shots AS
(
SELECT
  *,
  (101 IN UNNEST(tags.id)) AS isGoal,
  SQRT(
    POW((100 - positions[ORDINAL(1)].x) * 105/100, 2) +
    POW((60 - positions[ORDINAL(1)].y) * 68/100, 2)
  ) AS shotDistance
FROM
  \`$PROJECT_ID.soccer.$EVENT_NAME\`
WHERE
  eventName = 'Shot' OR (eventName = 'Free Kick' AND subEventName IN ('Free kick shot', 'Penalty'))
)
SELECT
  ROUND(shotDistance, 0) AS ShotDistRound0,
  COUNT(*) AS numShots,
  SUM(IF(isGoal, 1, 0)) AS numGoals,
  AVG(IF(isGoal, 1, 0)) AS goalPct
FROM
  Shots
WHERE
  shotDistance <= 50
GROUP BY
  ShotDistRound0
ORDER BY
  ShotDistRound0
"

# Task 4: Create Functions and ML Model
echo "Executing Task 4: Creating BigQuery Functions and Logistic Regression Model..."

# Create Distance Function
bq query --use_legacy_sql=false \
"
CREATE OR REPLACE FUNCTION \`$PROJECT_ID.soccer.$DIST_FUNC_NAME\`(x INT64, y INT64)
RETURNS FLOAT64
AS (
  SQRT(
    POW((120 - x) * 100/100, 2) +
    POW((55 - y) * 65/100, 2)
  )
);
"

# Create Angle Function
bq query --use_legacy_sql=false \
"
CREATE OR REPLACE FUNCTION \`$PROJECT_ID.soccer.$ANGLE_FUNC_NAME\`(x INT64, y INT64)
RETURNS FLOAT64
AS (
  SAFE.ACOS(
    SAFE_DIVIDE(
      (POW(100 - (x * 100/100), 2) + POW(32.5 + (7.32/2) - (y * 65/100), 2)) +
      (POW(100 - (x * 100/100), 2) + POW(32.5 - (7.32/2) - (y * 65/100), 2)) -
      POW(7.32, 2),
      (2 *
      SQRT(POW(100 - (x * 100/100), 2) + POW(32.5 + 7.32/2 - (y * 65/100), 2)) *
      SQRT(POW(100 - (x * 100/100), 2) + POW(32.5 - 7.32/2 - (y * 65/100), 2)))
    )
  ) * 180 / ACOS(-1)
);
"

# Train Machine Learning Model
bq query --use_legacy_sql=false \
"
CREATE OR REPLACE MODEL \`$PROJECT_ID.$MODEL_NAME\`
OPTIONS(
  model_type = 'LOGISTIC_REG',
  input_label_cols = ['isGoal']
) AS
SELECT
  Events.subEventName AS shotType,
  (101 IN UNNEST(Events.tags.id)) AS isGoal,
  \`$PROJECT_ID.soccer.$DIST_FUNC_NAME\`(Events.positions[ORDINAL(1)].x, Events.positions[ORDINAL(1)].y) AS shotDistance,
  \`$PROJECT_ID.soccer.$ANGLE_FUNC_NAME\`(Events.positions[ORDINAL(1)].x, Events.positions[ORDINAL(1)].y) AS shotAngle
FROM
  \`$PROJECT_ID.soccer.$EVENT_NAME\` Events
LEFT JOIN
  \`$PROJECT_ID.soccer.matches\` Matches ON Events.matchId = Matches.wyId
LEFT JOIN
  \`$PROJECT_ID.soccer.competitions\` Competitions ON Matches.competitionId = Competitions.wyId
WHERE
  Competitions.name != 'World Cup' AND
  (eventName = 'Shot' OR (eventName = 'Free Kick' AND subEventName IN ('Free kick shot', 'Penalty'))) AND
  \`$PROJECT_ID.soccer.$ANGLE_FUNC_NAME\`(Events.positions[ORDINAL(1)].x, Events.positions[ORDINAL(1)].y) IS NOT NULL;
"

# Completion Banner
echo ""
echo -e "\033[1;32m============================================\033[0m"
echo -e "\033[1;32m      LAB COMPLETED SUCCESSFULLY! 🎉       \033[0m"
echo -e "\033[1;32m============================================\033[0m"
echo ""
