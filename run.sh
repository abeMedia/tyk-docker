#!/bin/bash
set -e

cp .docker/tyk.conf ./tyk.conf
cp .docker/app.json ./apps/app.json

# set tyk config
sed -i "s/TYK_SECRET/$TYK_SECRET/g" ./tyk.conf
sed -i "s/REDIS_HOST/$REDIS_HOST/g" ./tyk.conf
sed -i "s/REDIS_PORT/$REDIS_PORT/g" ./tyk.conf
sed -i "s/REDIS_PASSWORD/$REDIS_PASSWORD/g" ./tyk.conf
sed -i "s/USE_SENTRY/$USE_SENTRY/g" ./tyk.conf
sed -i "s/SENTRY_DSN/$SENTRY_DSN/g" ./tyk.conf

# set api definition
sed -i "s/API_NAME/$API_NAME/g" ./apps/app.json
sed -i "s/API_ID/$API_ID/g" ./apps/app.json
sed -i "s/ORG_ID/$ORG_ID/g" ./apps/app.json
sed -i "s/USE_KEYLESS/$USE_KEYLESS/g" ./apps/app.json
sed -i "s/AUTH_HEADER_NAME/$AUTH_HEADER_NAME/g" ./apps/app.json
sed -i "s/AUTH_USE_PARAM/$AUTH_USE_PARAM/g" ./apps/app.json
sed -i "s#TARGET_URL#$TARGET_URL#g" ./apps/app.json
sed -i "s/ENABLE_BATCH_REQUESTS/$ENABLE_BATCH_REQUESTS/g" ./apps/app.json


if [ ! -z "$API_HEALTHCHECK_PATH" ]; then
  echo '{
    "name": "Health Check",
    "api_id": "health-check",
    "org_id": "'$ORG_ID'",
    "use_keyless": true,
    "proxy": {
        "listen_path": "'$API_HEALTHCHECK_PATH'",
        "target_url": "'$TARGET_URL'/'$API_HEALTHCHECK_PATH'",
        "strip_listen_path": true
    },
    "version_data": {
        "not_versioned": true
    }
}' > ./apps/health.json
fi

# set policies
POLICY_TEMPLATE=$(<.docker/policies.json)
POLICY_TEMPLATE="${POLICY_TEMPLATE//API_NAME/$API_NAME}"
POLICY_TEMPLATE="${POLICY_TEMPLATE//API_ID/$API_ID}"
POLICY_TEMPLATE="${POLICY_TEMPLATE//ORG_ID/$ORG_ID}"

function getVar()
{
    local var="$1"
    echo "${!var}"
}

POLICIES="{
"
i="1"
POLICY_ID="$POLICY_1_ID";
while [[ ! -z "$POLICY_ID" ]]; do
  POLICY_RATE=$(getVar POLICY_${i}_RATE)
  POLICY_PER=$(getVar POLICY_${i}_PER)
  POLICY_QUOTA_MAX=$(getVar POLICY_${i}_QUOTA_MAX)
  POLICY_QUOTA_RENEWAL_RATE=$(getVar POLICY_${i}_QUOTA_RENEWAL_RATE)

  POLICY="${POLICY_TEMPLATE//POLICY_ID/$POLICY_ID}"
  POLICY="${POLICY//POLICY_RATE/$POLICY_RATE}"
  POLICY="${POLICY//POLICY_PER/$POLICY_PER}"
  POLICY="${POLICY//POLICY_QUOTA_MAX/$POLICY_QUOTA_MAX}"
  POLICY="${POLICY//POLICY_QUOTA_RENEWAL_RATE/$POLICY_QUOTA_RENEWAL_RATE}"

  POLICIES+="$POLICY"
  ((i++))

  POLICY_ID=$(getVar POLICY_${i}_ID);
  if [ ! -z "$POLICY_ID" ]; then
    POLICIES+=",
"
  fi
done

POLICIES+="
}"

echo "$POLICIES" > ./policies/policies.json

tyk --conf ./tyk.conf
