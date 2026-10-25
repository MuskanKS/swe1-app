# SWE1 Django Application

[![Build Status](https://app.travis-ci.com/MuskanKS/swe1-app.svg?branch=main)](https://app.travis-ci.com/github/MuskanKS/swe1-app)

[![Coverage Status](https://coveralls.io/repos/github/MuskanKS/swe1-app/badge.svg?branch=main)](https://coveralls.io/github/MuskanKS/swe1-app?branch=main)

## About

A Django application developed for Software Engineering I.

## Continuous Integration

This project uses Travis CI to run:

- Django system checks and automated tests
- Black formatting checks
- Flake8 linting checks
- Coverage.py analysis
- Coveralls coverage reporting

## Running Locally

Install dependencies:

```bash
python -m pip install -r requirements.txt
```

Run Django tests:

```bash
python manage.py test
```

Check formatting:

```bash
black --check .
```

Run linting:

```bash
flake8 .
```

Run coverage:

```bash
coverage run --rcfile=.coveragerc manage.py test
coverage report --rcfile=.coveragerc -m
```