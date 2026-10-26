#!/bin/bash
set -euo pipefail
source /var/app/venv/*/bin/activate
export DJANGO_SETTINGS_MODULE=mysite.production_settings
python manage.py collectstatic --noinput
chown -R webapp:webapp staticfiles
test -s staticfiles/polls/style.css
