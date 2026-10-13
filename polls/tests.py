import datetime

from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from .models import Choice, Question


def create_question(question_text, days):
    """Create a question published a given number of days from now."""
    pub_date = timezone.now() + datetime.timedelta(days=days)
    return Question.objects.create(
        question_text=question_text,
        pub_date=pub_date,
    )


class QuestionModelTests(TestCase):
    def test_was_published_recently_with_recent_question(self):
        question = create_question("Recent question", -0.5)
        self.assertIs(question.was_published_recently(), True)

    def test_was_published_recently_with_old_question(self):
        question = create_question("Old question", -30)
        self.assertIs(question.was_published_recently(), False)

    def test_was_published_recently_with_future_question(self):
        question = create_question("Future question", 30)
        self.assertIs(question.was_published_recently(), False)


class QuestionIndexTests(TestCase):
    def test_no_questions(self):
        response = self.client.get(reverse("polls:index"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "No polls are available.")

    def test_future_question_is_not_displayed(self):
        create_question("Future question", 30)
        response = self.client.get(reverse("polls:index"))
        self.assertQuerySetEqual(
            response.context["latest_question_list"], []
        )

    def test_past_question_is_displayed(self):
        question = create_question("Past question", -5)
        response = self.client.get(reverse("polls:index"))
        self.assertQuerySetEqual(
            response.context["latest_question_list"], [question]
        )


class VotingTests(TestCase):
    def setUp(self):
        self.question = create_question("Favorite language?", -1)
        self.choice = Choice.objects.create(
            question=self.question,
            choice_text="Python",
            votes=0,
        )

    def test_vote_increases_vote_count(self):
        response = self.client.post(
            reverse("polls:vote", args=(self.question.id,)),
            {"choice": self.choice.id},
        )
        self.choice.refresh_from_db()
        self.assertEqual(self.choice.votes, 1)
        self.assertEqual(response.status_code, 302)

    def test_vote_without_selection_shows_error(self):
        response = self.client.post(
            reverse("polls:vote", args=(self.question.id,)),
            {},
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "You didn&#x27;t select a choice.")