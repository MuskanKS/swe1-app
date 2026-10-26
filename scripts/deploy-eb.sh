#!/usr/bin/env bash
set -euo pipefail

: "${EB_VERSION_LABEL:?Application version label is required}"
: "${AWS_ACCESS_KEY_ID:?AWS access key is required}"
: "${AWS_SECRET_ACCESS_KEY:?AWS secret key is required}"

export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""

APP_NAME="swe1-app"
ENV_NAME="swe1-env"
BUCKET="elasticbeanstalk-us-east-1-520519513900"
S3_KEY="travis-builds/${EB_VERSION_LABEL}.zip"
ZIP_FILE="/tmp/swe1-app.zip"

echo "Uploading application bundle..."
aws s3 cp "$ZIP_FILE" "s3://${BUCKET}/${S3_KEY}"

echo "Creating Elastic Beanstalk application version..."
aws elasticbeanstalk create-application-version \
  --application-name "$APP_NAME" \
  --version-label "$EB_VERSION_LABEL" \
  --source-bundle S3Bucket="$BUCKET",S3Key="$S3_KEY" \
  --process

echo "Waiting for application version processing..."

processed=false

for attempt in $(seq 1 60); do
  version_status=$(aws elasticbeanstalk describe-application-versions \
    --application-name "$APP_NAME" \
    --version-labels "$EB_VERSION_LABEL" \
    --query 'ApplicationVersions[0].Status' \
    --output text)

  echo "Application version status: $version_status"

  if [[ "$version_status" == "PROCESSED" ]]; then
    processed=true
    break
  fi

  if [[ "$version_status" == "FAILED" ]]; then
    echo "ERROR: AWS failed to process application version." >&2
    exit 1
  fi

  sleep 10
done

if [[ "$processed" != "true" ]]; then
  echo "ERROR: Application version processing timed out." >&2
  exit 1
fi

echo "Deploying processed application version..."

aws elasticbeanstalk update-environment \
  --environment-name "$ENV_NAME" \
  --version-label "$EB_VERSION_LABEL"

echo "Waiting for environment deployment..."

for attempt in $(seq 1 90); do
  state=$(aws elasticbeanstalk describe-environments \
    --environment-names "$ENV_NAME" \
    --query 'Environments[0].[Status,VersionLabel,Health]' \
    --output text)

  read -r status deployed health <<< "$state"

  echo "Deployment: $status, version: $deployed, health: $health"

  if [[ "$status" == "Ready" && \
        "$deployed" == "$EB_VERSION_LABEL" && \
        "$health" == "Green" ]]; then

    URL="http://swe1-env.eba-btdh4sap.us-east-1.elasticbeanstalk.com"

    curl --fail --silent --show-error --retry 3 \
      "$URL/polls/" --output /dev/null

    curl --fail --silent --show-error --retry 3 \
      "$URL/static/polls/style.css" --output /dev/null

    echo "Deployment verified: $EB_VERSION_LABEL"
    exit 0
  fi

  sleep 10
done

echo "ERROR: Deployment did not become healthy within 15 minutes." >&2
exit 1
