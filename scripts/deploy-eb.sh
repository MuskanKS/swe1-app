#!/usr/bin/env bash
set -euo pipefail

: "${EB_VERSION_LABEL:?An explicit application version is required}"
export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""

# The provider uploads the bundle; use the known label for the environment update.
version=$(aws elasticbeanstalk describe-application-versions \
  --application-name swe1-app --version-labels "$EB_VERSION_LABEL" \
  --query 'ApplicationVersions[0].VersionLabel' --output text)
test "$version" = "$EB_VERSION_LABEL"
aws elasticbeanstalk update-environment --environment-name swe1-env \
  --version-label "$EB_VERSION_LABEL" --query 'Status' --output text

for attempt in $(seq 1 90); do
  state=$(aws elasticbeanstalk describe-environments \
    --environment-names swe1-env \
    --query 'Environments[0].[Status,VersionLabel,Health]' --output text)
  read -r status deployed health <<< "$state"
  printf 'Deployment: %s, version: %s, health: %s\n' "$status" "$deployed" "$health"
  if [[ "$status" = Ready ]]; then
    if [[ "$deployed" != "$EB_VERSION_LABEL" ]]; then
      echo 'Deployment failed: AWS is running a different application version.' >&2
      exit 1
    fi
    if [[ "$health" = Green ]]; then
      url=http://swe1-env.eba-btdh4sap.us-east-1.elasticbeanstalk.com
      curl --fail --silent --show-error --retry 3 "$url/polls/" --output /dev/null
      curl --fail --silent --show-error --retry 3 "$url/static/polls/style.css" --output /dev/null
      echo "Deployment verified: $EB_VERSION_LABEL"
      exit 0
    fi
  fi
  sleep 10
done

echo 'Deployment did not become healthy within 15 minutes.' >&2
exit 1
