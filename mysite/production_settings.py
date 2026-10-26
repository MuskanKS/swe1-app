"""Settings for the Elastic Beanstalk assignment environment."""

import os

from .settings import *  # noqa: F403

DEBUG = False
SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
ALLOWED_HOSTS = [
    "swe1-env.eba-btdh4sap.us-east-1.elasticbeanstalk.com",
    "localhost",
    "127.0.0.1",
]
STATIC_ROOT = BASE_DIR / "staticfiles"  # noqa: F405
ROOT_URLCONF = "mysite.production_urls"

# Keep this single-instance demo database across application redeployments.
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": "/var/app/data/db.sqlite3",
    }
}
