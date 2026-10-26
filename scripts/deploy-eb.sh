#!/usr/bin/env bash
set -euo pipefail

# Required Travis CI environment variables
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
URL="http://swe1-env.eba-btdh4sap.us-east-1.elasticbeanstalk.com"

# Display recent Elastic Beanstalk errors when deployment fails.
show_eb_errors() {
  echo ""
  echo "========== Recent Elastic Beanstalk Errors =========="

  aws elasticbeanstalk describe-events \
    --application-name "$APP_NAME" \
    --environment-name "$ENV_NAME" \
    --severity ERROR \
    --max-items 10 \
    --query 'Events[*].[EventDate,Message]' \
    --output table || true

  echo "====================================================="
}

echo "Checking application bundle..."

if [[ ! -f "$ZIP_FILE" ]]; then
  echo "ERROR: Application bundle not found: $ZIP_FILE" >&2
  exit 1
fi

# Step 1: Upload application bundle
echo "Uploading application bundle..."

aws s3 cp \
  "$ZIP_FILE" \
  "s3://${BUCKET}/${S3_KEY}"

# Step 2: Create Elastic Beanstalk application version
echo "Creating Elastic Beanstalk application version..."

aws elasticbeanstalk create-application-version \
  --application-name "$APP_NAME" \
  --version-label "$EB_VERSION_LABEL" \
  --source-bundle S3Bucket="$BUCKET",S3Key="$S3_KEY" \
  --process

# Step 3: Wait for AWS to finish processing the version
echo "Waiting for application version processing..."

processed=false

for attempt in $(seq 1 60); do

  version_status=$(aws elasticbeanstalk describe-application-versions \
    --application-name "$APP_NAME" \
    --version-labels "$EB_VERSION_LABEL" \
    --query 'ApplicationVersions[0].Status' \
    --output text)

  echo "Attempt $attempt/60: Version status = $version_status"

  case "${version_status^^}" in

    PROCESSED)
      echo "Application version processed successfully."
      processed=true
      break
      ;;

    FAILED)
      echo "ERROR: AWS failed to process application version." >&2
      show_eb_errors
      exit 1
      ;;

    PROCESSING|UNPROCESSED|NONE)
      sleep 10
      ;;

    *)
      echo "ERROR: Unexpected application version status: $version_status" >&2
      show_eb_errors
      exit 1
      ;;

  esac

done

if [[ "$processed" != "true" ]]; then
  echo "ERROR: Application version processing timed out." >&2
  show_eb_errors
  exit 1
fi

# Step 4: Deploy the processed version
echo "Deploying application version: $EB_VERSION_LABEL"

aws elasticbeanstalk update-environment \
  --environment-name "$ENV_NAME" \
  --version-label "$EB_VERSION_LABEL"

# Step 5: Wait for environment to become healthy
echo "Waiting for Elastic Beanstalk deployment..."

deployed_successfully=false

for attempt in $(seq 1 90); do

  state=$(aws elasticbeanstalk describe-environments \
    --environment-names "$ENV_NAME" \
    --query 'Environments[0].[Status,VersionLabel,Health]' \
    --output text)

  read -r status deployed health <<< "$state"

  echo "Attempt $attempt/90: Status=$status, Version=$deployed, Health=$health"

  if [[ "$status" == "Ready" && \
        "$deployed" == "$EB_VERSION_LABEL" && \
        "$health" == "Green" ]]; then

    deployed_successfully=true
    break
  fi

  sleep 10

done

if [[ "$deployed_successfully" != "true" ]]; then
  echo "ERROR: Deployment did not become healthy within 15 minutes." >&2
  show_eb_errors
  exit 1
fi

# Step 6: Smoke tests
echo "Running application smoke tests..."

curl --fail --silent --show-error --retry 3 \
  "$URL/polls/" \
  --output /dev/null

curl --fail --silent --show-error --retry 3 \
  "$URL/static/polls/style.css" \
  --output /dev/null

echo ""
echo "=========================================="
echo "DEPLOYMENT SUCCESSFUL"
echo "Application: $APP_NAME"
echo "Environment: $ENV_NAME"
echo "Version: $EB_VERSION_LABEL"
echo "URL: $URL"
echo "=========================================="
