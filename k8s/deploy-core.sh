#!/bin/bash
# deploy-core.sh - Deploy core app stack WITHOUT Datadog (simpler, faster)
# Includes: Metrics Server, Django app, Nginx Ingress, HPA
# Usage: ./deploy-core.sh

set -e

echo "========================================="
echo "Little Lemon K8s Core Stack Deployment"
echo "(No Datadog - for basic testing)"
echo "========================================="

# Step 0: Verify cluster
echo "[1/6] Verifying EKS cluster access..."
kubectl cluster-info | head -n 2
kubectl get nodes -o wide

# Step 1: Install metrics-server
echo "[2/6] Installing metrics-server..."
kubectl apply -f metrics-server.yaml
kubectl -n kube-system wait --for=condition=Ready pod -l k8s-app=metrics-server --timeout=300s || echo "Metrics-server ready or already installed"

# Step 2: Deploy app
echo "[3/6] Deploying Django application..."
kubectl apply -f django-deployment.yaml
kubectl apply -f django-service.yaml
kubectl wait --for=condition=Ready pod -l app=little-lemon --timeout=300s || echo "Pod starting, may take time..."

# Step 3: Install Nginx Ingress
echo "[4/6] Installing Nginx Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm repo update
kubectl create namespace ingress-nginx || true
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --wait

echo "[5/6] Creating Ingress resource..."
kubectl apply -f nginx-ingress.yaml

# Step 4: Apply HPA
echo "[6/6] Creating Horizontal Pod Autoscaler..."
kubectl apply -f hpa.yaml

# Display status and endpoints
echo ""
echo "========================================="
echo "Core Stack Deployment Complete!"
echo "========================================="
echo ""
echo "Nodes:"
kubectl get nodes -o wide

echo ""
echo "Pods (app):"
kubectl get pods -l app=little-lemon -o wide

echo ""
echo "HPA:"
kubectl get hpa

echo ""
echo "Ingress Controller External IP (NLB):"
EXTERNAL_IP=$(kubectl -n ingress-nginx get svc nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
echo "http://$EXTERNAL_IP"

echo ""
echo "Quick tests:"
echo "1. Wait for external IP (may take 2-3 min): kubectl -n ingress-nginx get svc -w"
echo "2. Test app: curl -I http://$EXTERNAL_IP/"
echo "3. Generate load: kubectl run load-gen --image=busybox --restart=Never -- sh -c \"while true; do wget -q -O- http://little-lemon-service/; done\""
echo "4. Watch HPA scale: kubectl get hpa -w"
echo ""
echo "To add Datadog later:"
echo "  export DATADOG_API_KEY='<datadog_api_key>'"
echo "  helm repo add datadog https://helm.datadoghq.com && helm repo update"
echo "  helm upgrade --install datadog-agent datadog/datadog -f datadog-values.yaml --namespace datadog --force"
echo ""
