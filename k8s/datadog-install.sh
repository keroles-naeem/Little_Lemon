#!/bin/sh
# Simple script to install Datadog agent via Helm (requires DATADOG_API_KEY env var)
set -e
if [ -z "$DATADOG_API_KEY" ]; then
  echo "Please set DATADOG_API_KEY environment variable"
  exit 1
fi
helm repo add datadog https://helm.datadoghq.com
helm repo update
helm install datadog-agent datadog/datadog \
  --set datadog.apiKey=$DATADOG_API_KEY \
  --set datadog.site="datadoghq.com" \
  --set clusterAgent.enabled=true \
  --set clusterAgent.replicas=1 \
  --set clusterAgent.metricsProvider.enabled=true

echo "Datadog agent installed. Visit Datadog UI to configure dashboards and alerts."
