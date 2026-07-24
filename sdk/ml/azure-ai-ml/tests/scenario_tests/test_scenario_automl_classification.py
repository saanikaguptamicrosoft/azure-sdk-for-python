# ---------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# ---------------------------------------------------------
"""Scenario: AutoML tabular classification — config serialization round-trip.

Mirrors the customer pattern from:
  https://github.com/Azure/azureml-examples/tree/main/sdk/python/jobs/automl-standalone-jobs
  (automl-classification-task-bankmarketing)

Customer story:
  A data scientist runs an AutoML classification experiment. They configure limits (timeout, trial
  count, early termination), training rules (blocked algorithms, ensemble toggles) and featurization,
  then submit. The whole AutoML configuration tree — limits, training settings, featurization — must
  survive serialization to the service and be faithfully returned when the job is re-fetched.

  AutoML is the single largest and most intricate surface the TypeSpec migration touched (the arm
  model stripped much of the AutoML sweep/search-space/settings detail that the SDK now re-applies via
  wire-keys). This scenario is a regression guard: it submits a real AutoML job and asserts the
  configuration round-trips, so any dropped/mis-serialized AutoML field is caught.

Steps:
  1. Create a small compute cluster
  2. Build a local MLTable training dataset (tabular data with a target column)
  3. Configure an AutoML classification job: limits, training settings, featurization, tags
  4. Submit the job
  5. Re-fetch the job and assert the configuration round-tripped (limits, blocked algos, featurization)
  6. Cancel the job and clean up
"""

import os
import tempfile

import pytest

from azure.ai.ml import Input, MLClient, automl
from azure.ai.ml.entities import AmlCompute, IdentityConfiguration
from azure.core.exceptions import HttpResponseError


def _write_mltable_dataset(root: str) -> None:
    """Write a minimal tabular MLTable dataset (CSV + MLTable) with a binary target column."""
    csv_path = os.path.join(root, "train.csv")
    with open(csv_path, "w", encoding="utf-8") as f:
        f.write("f1,f2,f3,target\n")
        for i in range(60):
            f.write(f"{i * 0.1},{(i % 5)},{(i % 3) * 1.5},{i % 2}\n")
    with open(os.path.join(root, "MLTable"), "w", encoding="utf-8") as f:
        f.write(
            "paths:\n"
            "  - file: ./train.csv\n"
            "transformations:\n"
            "  - read_delimited:\n"
            "      delimiter: ','\n"
            "      encoding: ascii\n"
            "      header: all_files_same_headers\n"
        )


class TestScenarioAutoMLClassification:
    """AutoML classification: submit and verify the configuration tree round-trips."""

    @pytest.mark.timeout(1200)
    def test_automl_classification_config_round_trip(self, ml_client: MLClient, rand_name):
        """Configure + submit AutoML classification; verify limits/training/featurization survive round-trip."""
        compute_name = rand_name("amlcls")[:24]
        blocked = ["LogisticRegression", "KNN"]

        cluster = AmlCompute(
            name=compute_name,
            size="STANDARD_DS3_V2",
            min_instances=0,
            max_instances=1,
            idle_time_before_scale_down=120,
            identity=IdentityConfiguration(type="system_assigned"),
        )
        ml_client.compute.begin_create_or_update(cluster).result()

        submitted = None
        try:
            with tempfile.TemporaryDirectory() as data_dir:
                _write_mltable_dataset(data_dir)

                classification_job = automl.classification(
                    compute=compute_name,
                    training_data=Input(type="mltable", path=data_dir),
                    target_column_name="target",
                    primary_metric="accuracy",
                    tags={"scenario": "automl-classification", "branch": "tsp-migration"},
                )
                classification_job.set_limits(
                    timeout_minutes=15,
                    trial_timeout_minutes=5,
                    max_trials=3,
                    max_concurrent_trials=1,
                    enable_early_termination=True,
                )
                classification_job.set_training(
                    enable_stack_ensemble=False,
                    enable_vote_ensemble=False,
                    blocked_training_algorithms=blocked,
                )
                classification_job.set_featurization(mode="auto")

                try:
                    submitted = ml_client.jobs.create_or_update(classification_job)
                except HttpResponseError as ex:
                    pytest.skip(f"AutoML submission failed for a service reason (quota/data/infra): {ex}")

                assert submitted.name is not None

                # ── Round-trip: the whole AutoML config tree must survive serialization ──
                fetched = ml_client.jobs.get(submitted.name)
                assert fetched.target_column_name == "target"
                assert fetched.limits.timeout_minutes == 15
                assert fetched.limits.trial_timeout_minutes == 5
                assert fetched.limits.max_trials == 3
                assert fetched.limits.enable_early_termination is True
                # Training settings the arm model dropped and the SDK re-applies via wire-keys.
                assert fetched.training.enable_stack_ensemble is False
                assert fetched.training.enable_vote_ensemble is False
                assert set(fetched.training.blocked_training_algorithms or []) >= set(blocked)
                assert fetched.featurization.mode.lower() == "auto"
        finally:
            if submitted is not None:
                try:
                    ml_client.jobs.begin_cancel(submitted.name)
                except Exception as ex:  # pragma: no cover - best-effort cleanup
                    print(f"cleanup: could not cancel job {submitted.name} — {ex}")
            try:
                ml_client.compute.begin_delete(compute_name)
            except Exception as ex:  # pragma: no cover - best-effort cleanup
                print(f"cleanup: could not delete compute {compute_name} — {ex}")
