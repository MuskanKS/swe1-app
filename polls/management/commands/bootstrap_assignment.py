"""Provision the assignment admin and sample polls when explicitly configured."""

import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from polls.models import Choice, Question


class Command(BaseCommand):
    help = "Create the initial assignment admin and sample polls."

    @transaction.atomic
    def handle(self, *args, **options):
        username = os.environ.get("ASSIGNMENT_ADMIN_USERNAME")
        password = os.environ.get("ASSIGNMENT_ADMIN_PASSWORD")
        if not username or not password:
            self.stdout.write("Admin bootstrap is not configured; skipping.")
            return
        user_model = get_user_model()
        if not user_model.objects.filter(username=username).exists():
            if len(password) < 16:
                raise CommandError("Use an administrator password of 16+ characters.")
            user_model.objects.create_superuser(username=username, password=password)
            self.stdout.write("Assignment administrator created.")
        for title, answers in [
            (
                "[Test] Which programming language do you prefer?",
                ["Python", "Java", "JavaScript"],
            ),
            (
                "[Test] Which study format do you prefer?",
                ["In person", "Online", "Hybrid"],
            ),
        ]:
            question, created = Question.objects.get_or_create(
                question_text=title, defaults={"pub_date": timezone.now()}
            )
            if created:
                for answer in answers:
                    Choice.objects.create(question=question, choice_text=answer)
        self.stdout.write("Sample polls are ready.")
