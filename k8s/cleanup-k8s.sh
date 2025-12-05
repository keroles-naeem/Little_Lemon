#!/bin/bash
# cleanup-k8s.sh - Remove all Little Lemon Kubernetes resources from the cluster
# WARNING: This will delete deployments, services, ingress, HPA, and monitoring agents
# Usage: ./cleanup-k8s.sh

set -e

echo "========================================="
echo "Little Lemon K8s Cleanup"
echo "========================================="
echo "WARNING: This will remove all deployed resources!"
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

# Remove app and ingress
echo "[1/6] Removing Django deployment and service..."
kubectl delete -f django-deployment.yaml --ignore-not-found=true
kubectl delete -f django-service.yaml --ignore-not-found=true
kubectl delete -f nginx-ingress.yaml --ignore-not-found=true
echo "Done."

# Remove HPA
echo "[2/6] Removing HPA..."
kubectl delete -f hpa.yaml --ignore-not-found=true
echo "Done."

# Uninstall Nginx Ingress Helm release
echo "[3/6] Uninstalling Nginx Ingress..."
helm uninstall nginx-ingress -n ingress-nginx --ignore-not-found=true 2>/dev/null || true
kubectl delete namespace ingress-nginx --ignore-not-found=true
echo "Done."

# Uninstall Datadog Helm release
echo "[4/6] Uninstalling Datadog Agent..."
helm uninstall datadog-agent -n datadog --ignore-not-found=true 2>/dev/null || true
helm uninstall datadog-agent -n default --ignore-not-found=true 2>/dev/null || true
kubectl delete secret datadog-api -n datadog --ignore-not-found=true
# Remove orphaned Datadog ClusterRoles that may conflict on redeploy
kubectl delete clusterrole datadog-agent-cluster-agent --ignore-not-found=true
kubectl delete clusterrole datadog-agent --ignore-not-found=true
kubectl delete clusterrolebinding datadog-agent-cluster-agent --ignore-not-found=true
kubectl delete clusterrolebinding datadog-agent --ignore-not-found=true
# Clean up Datadog resources in all namespaces
kubectl delete daemonset -A -l app=datadog-agent --ignore-not-found=true
kubectl delete deployment -A -l app=datadog-agent --ignore-not-found=true
kubectl delete svc -A -l app=datadog-agent --ignore-not-found=true
kubectl delete namespace datadog --ignore-not-found=true
echo "Done."

# Remove metrics-server
echo "[5/6] Removing Metrics Server..."
kubectl delete -f metrics-server.yaml --ignore-not-found=true
echo "Done."

# Summary
echo "[6/6] Cleanup complete!"
echo "======================================"
echo ""
echo "Remaining resources:"
kubectl get all -A | grep -v "kube-" || echo "No application resources found"

echo ""
echo "To also delete the EKS cluster and AWS infrastructure:"
echo "  cd ../terraform"
echo "  terraform destroy"
echo ""
