#!/bin/bash
# Complete deployment script for Little Lemon K8s stack
# Usage: ./deploy-all.sh
# Prerequisites: kubectl, helm, AWS CLI configured

set -e

echo "========================================="
echo "Little Lemon K8s Full Stack Deployment"
echo "========================================="

# Step 0: Verify cluster
echo "[1/8] Verifying EKS cluster access..."
kubectl cluster-info | head -n 2
kubectl get nodes -o wide

# Step 1: Install metrics-server
echo "[2/8] Installing metrics-server..."
kubectl apply -f metrics-server.yaml
kubectl -n kube-system wait --for=condition=Ready pod -l k8s-app=metrics-server --timeout=300s || echo "Metrics-server ready or already installed"

# Step 2: Deploy app
echo "[3/8] Deploying Django application..."
kubectl apply -f django-deployment.yaml
kubectl apply -f django-service.yaml
kubectl wait --for=condition=Ready pod -l app=little-lemon --timeout=300s || echo "Pod starting, may take time..."

# Step 3: Install Nginx Ingress
echo "[4/8] Installing Nginx Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm repo update
kubectl create namespace ingress-nginx || true
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --wait

echo "[5/8] Creating Ingress resource..."
kubectl apply -f nginx-ingress.yaml

# Step 4: Apply HPA
echo "[6/8] Creating Horizontal Pod Autoscaler..."
kubectl apply -f hpa.yaml

# Step 5: Install Datadog (if API key provided)
if [ -z "$DATADOG_API_KEY" ]; then
  echo "[7/8] Datadog API key not set (DATADOG_API_KEY env var). Skipping Datadog installation."
  echo "       To install Datadog later, set DATADOG_API_KEY and run: helm install -f datadog-values.yaml"
else
  echo "[7/8] Installing Datadog Agent..."
  kubectl create namespace datadog || true
  kubectl create secret generic datadog-api \
    --from-literal=api-key="$DATADOG_API_KEY" \
    -n datadog \
    --dry-run=client -o yaml | kubectl apply -f -
  
  helm repo add datadog https://helm.datadoghq.com || true
  helm repo update
  helm upgrade --install datadog-agent datadog/datadog \
    -f datadog-values.yaml \
    --namespace datadog \
    --force --cleanup-on-fail \
    --wait
fi

# Step 6: Display status and endpoints
echo "[8/8] Deployment complete! Status:"
echo "======================================"
echo ""
echo "Nodes:"
kubectl get nodes -o wide

echo ""
echo "Pods:"
kubectl get pods -A | grep -E "little-lemon|nginx|datadog|metrics-server"

echo ""
echo "HPA:"
kubectl get hpa

echo ""
echo "Ingress Controller External IP (NLB):"
EXTERNAL_IP=$(kubectl -n ingress-nginx get svc nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
echo "http://$EXTERNAL_IP"

echo ""
echo "Next steps:"
echo "1. Wait for metrics-server to collect data (2-3 minutes)"
echo "2. Test app: curl -I http://$EXTERNAL_IP/"
echo "3. Generate load: kubectl run load-gen --image=busybox --restart=Never -- sh -c \"while true; do wget -q -O- http://little-lemon-service/; done\""
echo "4. Watch HPA: kubectl get hpa -w"
echo "5. View Datadog dashboards: https://app.datadoghq.com"
echo ""
