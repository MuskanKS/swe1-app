#!/usr/bin/env bash
set -euo pipefail

# Required Travis CI environment variables
: "${EB_VERSION_LABEL:?Application version label is required}"
: "${AWS_ACCESS_KEY_ID:?AWS access key is required}"
: "${AWS_SECRET_ACCESS_KEY:?AWS secret key is required}"

export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""

# AWS Elastic Beanstalk configuration
APP_NAME="swe1-app"
ENV_NAME="swe1-env"
BUCKET="elasticbeanstalk-us-east-1-520519513900"

S3_KEY="travis-builds/${EB_VERSION_LABEL}.zip"
ZIP_FILE="/tmp/swe1-app.zip"

URL="http://swe1-env.eba-btdh4sap.us-east-1.elasticbeanstalk.com"

# --------------------------------------------------
# Helper: Display recent Elastic Beanstalk errors
# --------------------------------------------------

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

# --------------------------------------------------
# Step 1: Validate application bundle
# --------------------------------------------------

echo "Checking application bundle..."

if [[ ! -f "$ZIP_FILE" ]]; then
  echo "ERROR: Application bundle not found: $ZIP_FILE" >&2
  exit 1
fi

echo "Application bundle found."

# --------------------------------------------------
# Step 2: Upload ZIP to Amazon S3
# --------------------------------------------------

echo "Uploading application bundle..."

aws s3 cp \
  "$ZIP_FILE" \
  "s3://${BUCKET}/${S3_KEY}"

echo "Application bundle uploaded successfully."

# --------------------------------------------------
# Step 3: Create Elastic Beanstalk application version
# --------------------------------------------------

echo "Creating Elastic Beanstalk application version..."

# Do not use --process.
# Elastic Beanstalk can deploy an UNPROCESSED version directly.

aws elasticbeanstalk create-application-version \
  --application-name "$APP_NAME" \
  --version-label "$EB_VERSION_LABEL" \
  --source-bundle S3Bucket="$BUCKET",S3Key="$S3_KEY"

echo "Application version created successfully."

# --------------------------------------------------
# Step 4: Deploy application version
# --------------------------------------------------

echo "Deploying application version: $EB_VERSION_LABEL"

aws elasticbeanstalk update-environment \
  --environment-name "$ENV_NAME" \
  --version-label "$EB_VERSION_LABEL"

echo "Deployment request submitted."

# --------------------------------------------------
# Step 5: Wait for deployment to finish
# --------------------------------------------------

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

    echo "Elastic Beanstalk deployment completed successfully."

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

# --------------------------------------------------
# Step 6: Smoke test application
# --------------------------------------------------

echo "Running application smoke tests..."

echo "Checking Django polls page..."

curl \
  --fail \
  --silent \
  --show-error \
  --retry 3 \
  "$URL/polls/" \
  --output /dev/null

echo "Django polls page passed."

echo "Checking static CSS..."

curl \
  --fail \
  --silent \
  --show-error \
  --retry 3 \
  "$URL/static/polls/style.css" \
  --output /dev/null

echo "Static CSS passed."

# --------------------------------------------------
# Step 7: Deployment success
# --------------------------------------------------

echo ""
echo "=========================================="
echo "DEPLOYMENT SUCCESSFUL"
echo "=========================================="
echo "Application: $APP_NAME"
echo "Environment: $ENV_NAME"
echo "Version: $EB_VERSION_LABEL"
echo "URL: $URL"
echo "=========================================="
