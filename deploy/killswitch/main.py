"""Detaches billing from this project when the budget alert fires.

Wired as: Budget -> Pub/Sub topic -> this Cloud Function. With billing
detached, Google stops everything that costs money (the VM is shut down),
so a runaway cost can't keep growing.
"""
import base64
import json
import os

import functions_framework
from googleapiclient import discovery

PROJECT_ID = os.environ["GCP_PROJECT"]


@functions_framework.cloud_event
def stop_billing(cloud_event):
    data = json.loads(base64.b64decode(cloud_event.data["message"]["data"]))
    cost = data["costAmount"]
    budget = data["budgetAmount"]
    print(f"cost={cost} budget={budget}")
    if cost <= budget:
        return  # Under budget: just a progress notification.

    billing = discovery.build("cloudbilling", "v1", cache_discovery=False)
    projects = billing.projects()
    name = f"projects/{PROJECT_ID}"
    info = projects.getBillingInfo(name=name).execute()
    if not info.get("billingEnabled"):
        print("Billing already disabled")
        return
    projects.updateBillingInfo(
        name=name, body={"billingAccountName": ""}
    ).execute()
    print("Billing disabled")
