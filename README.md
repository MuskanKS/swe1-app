# SWE1 Django Application

[![Build Status](https://app.travis-ci.com/MuskanKS/swe1-app.svg?branch=main)](https://app.travis-ci.com/github/MuskanKS/swe1-app)
[![Coverage Status](https://coveralls.io/repos/github/MuskanKS/swe1-app/badge.svg?branch=main)](https://coveralls.io/github/MuskanKS/swe1-app?branch=main)

A Django polls application for Software Engineering I.

[Live application](http://swe1-env.eba-btdh4sap.us-east-1.elasticbeanstalk.com/polls/)

## Run locally

```bash
python -m pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

## Checks

```bash
python manage.py test
black --check .
flake8 .
coverage run --rcfile=.coveragerc manage.py test
coverage report --rcfile=.coveragerc -m
```

Travis CI checks pushes and pull requests and reports coverage to Coveralls.
Successful builds on `main` deploy to Elastic Beanstalk.

## Deployment

AWS Elastic Beanstalk: `swe1-env`, `us-east-1`, Python 3.12.

Include `.ebextensions` and `.platform` in the deployment package.
Set `DJANGO_SETTINGS_MODULE=mysite.production_settings` and
`DJANGO_SECRET_KEY` in AWS. Keep credentials out of Git.

The SQLite database survives application redeployments on the same instance,
but not instance replacement.

In Travis repository settings, configure `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, and `COVERALLS_REPO_TOKEN` with values hidden from logs.
Pull request builds run checks without deploying.
