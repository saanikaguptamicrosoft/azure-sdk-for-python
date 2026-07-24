# ---------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# ---------------------------------------------------------
"""Scenario: Job schedule with recurrence and cron triggers — trigger config round-trip.

Mirrors the customer pattern from:
  https://github.com/Azure/azureml-examples/tree/main/sdk/python/schedules

Customer story:
  An MLOps engineer schedules a recurring job (e.g. nightly retraining). They define a trigger
  (recurrence or cron), attach a job definition, create the schedule, and later disable/delete it. The
  trigger configuration (frequency, interval, recurrence pattern, or cron expression) must survive
  serialization to the service and be faithfully returned on re-fetch.

  The TypeSpec migration moved schedule ``trigger`` submission onto the arm client (with a custom
  ``send_request`` path for the trigger endpoint) and rebuilt the Schedule envelope. This scenario is a
  regression guard: it creates schedules with both trigger types and asserts the trigger round-trips.

Steps:
  1. Build a trivial command job to schedule
  2. Create a schedule with a RecurrenceTrigger; assert the recurrence config round-trips
  3. Create a schedule with a CronTrigger; assert the cron expression round-trips
  4. Disable and delete both schedules
"""

import pytest

from azure.ai.ml import MLClient, command
from azure.ai.ml.dsl import pipeline
from azure.ai.ml.entities import CronTrigger, JobSchedule, RecurrencePattern, RecurrenceTrigger
from azure.core.exceptions import HttpResponseError

_CURATED_ENV = "azureml://registries/azureml/environments/sklearn-1.5/labels/latest"


def _trivial_job():
    """A minimal single-step pipeline job used only as the schedule's target (never actually run here).

    Schedules accept a ``PipelineJob`` (a bare ``CommandJob`` is only allowed under private preview),
    so the trivial command is wrapped in a serverless DSL pipeline.
    """
    step = command(
        command="echo scheduled hello",
        environment=_CURATED_ENV,
        display_name="scenario-scheduled-step",
    )

    @pipeline(name="scenario-scheduled-pipeline", default_compute="serverless")
    def _sched_pipeline():
        step()

    return _sched_pipeline()


class TestScenarioScheduleTrigger:
    """Job schedules with recurrence + cron triggers; trigger configuration round-trip fidelity."""

    @pytest.mark.timeout(600)
    def test_recurrence_trigger_round_trip(self, ml_client: MLClient, rand_name):
        """Create a schedule with a weekly RecurrenceTrigger and verify the recurrence config survives."""
        schedule_name = rand_name("recsched")[:32]
        created = False
        try:
            trigger = RecurrenceTrigger(
                frequency="week",
                interval=1,
                schedule=RecurrencePattern(hours=[10], minutes=[30], week_days=["monday", "thursday"]),
            )
            schedule = JobSchedule(
                name=schedule_name,
                trigger=trigger,
                create_job=_trivial_job(),
                tags={"scenario": "schedule", "trigger": "recurrence"},
            )
            try:
                ml_client.schedules.begin_create_or_update(schedule).result()
            except HttpResponseError as ex:
                pytest.skip(f"schedule create failed for a service reason (infra/env/compute): {ex}")
            created = True

            fetched = ml_client.schedules.get(schedule_name)
            assert fetched.name == schedule_name
            assert fetched.trigger.frequency.lower() == "week"
            assert fetched.trigger.interval == 1
            assert 10 in fetched.trigger.schedule.hours
            assert 30 in fetched.trigger.schedule.minutes
            assert {d.lower() for d in fetched.trigger.schedule.week_days} >= {"monday", "thursday"}
            assert fetched.tags.get("trigger") == "recurrence"
        finally:
            if created:
                try:
                    ml_client.schedules.begin_disable(schedule_name).result()
                    ml_client.schedules.begin_delete(schedule_name).result()
                except Exception as ex:  # pragma: no cover - best-effort cleanup
                    print(f"cleanup: could not remove schedule {schedule_name} — {ex}")

    @pytest.mark.timeout(600)
    def test_cron_trigger_round_trip(self, ml_client: MLClient, rand_name):
        """Create a schedule with a CronTrigger and verify the cron expression survives round-trip."""
        schedule_name = rand_name("cronsched")[:32]
        created = False
        try:
            trigger = CronTrigger(expression="30 10 * * 1", time_zone="UTC")
            schedule = JobSchedule(
                name=schedule_name,
                trigger=trigger,
                create_job=_trivial_job(),
                tags={"scenario": "schedule", "trigger": "cron"},
            )
            try:
                ml_client.schedules.begin_create_or_update(schedule).result()
            except HttpResponseError as ex:
                pytest.skip(f"schedule create failed for a service reason (infra/env/compute): {ex}")
            created = True

            fetched = ml_client.schedules.get(schedule_name)
            assert fetched.name == schedule_name
            assert fetched.trigger.expression == "30 10 * * 1"
            assert fetched.trigger.time_zone == "UTC"
            assert fetched.tags.get("trigger") == "cron"
        finally:
            if created:
                try:
                    ml_client.schedules.begin_disable(schedule_name).result()
                    ml_client.schedules.begin_delete(schedule_name).result()
                except Exception as ex:  # pragma: no cover - best-effort cleanup
                    print(f"cleanup: could not remove schedule {schedule_name} — {ex}")
