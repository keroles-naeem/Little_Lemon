# Little Lemon EKS Kubernetes Deployment - Complete Guide

## Prerequisites
- AWS EKS cluster (Terraform setup in `../terraform/` directory)
- `kubectl` configured and connected to EKS cluster
- `helm` 3.x installed locally
- Datadog account with API key (get from https://app.datadoghq.com or https://app.datadoghq.eu)

## Quick Start (Copy/Paste Commands)

### Step 0: Verify Cluster Access
```bash
aws eks update-kubeconfig --region us-east-1 --name little-lemon-cluster
kubectl get nodes -o wide
kubectl get pods -A | head -n 20
```

### Step 1: Install Metrics Server (Required for HPA)
Metrics Server collects CPU and memory metrics from kubelet. Required for Horizontal Pod Autoscaler (HPA).

**Option A: Use our manifest (recommended for reproducibility)**
```bash
cd k8s
kubectl apply -f metrics-server.yaml
```

**Option B: Use official upstream YAML**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Verify installation:
```bash
kubectl -n kube-system get pods | grep metrics-server
kubectl -n kube-system logs -l k8s-app=metrics-server -f  # check logs
```

Wait until pods show `Running` (may take 30 seconds):
```bash
kubectl -n kube-system wait --for=condition=Ready pod -l k8s-app=metrics-server --timeout=300s
```

### Step 2: Deploy Little Lemon Application
Deploy the Django app with resource requests/limits and health probes.

```bash
cd k8s
kubectl apply -f django-deployment.yaml
kubectl apply -f django-service.yaml
```

Verify pod is running:
```bash
kubectl get pods -o wide
kubectl describe pod <pod-name>
```

### Step 3: Install Nginx Ingress Controller (External Entry Point)
Nginx Ingress Controller exposes your service to the internet via AWS NLB (Network Load Balancer).

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

kubectl create namespace ingress-nginx || true

helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb"
```

Apply Ingress resource (routes traffic to Django service):
```bash
kubectl apply -f nginx-ingress.yaml
```

Wait for AWS to provision the NLB (1-3 minutes). Watch the external IP appear:
```bash
kubectl -n ingress-nginx get svc -w
# Ctrl+C when nginx-ingress-ingress-nginx-controller shows an EXTERNAL-IP

# Or check once:
kubectl -n ingress-nginx get svc nginx-ingress-ingress-nginx-controller -o wide
```

Save the EXTERNAL-IP (NLB hostname) — this is your public access point:
```bash
INGRESS_IP=$(kubectl -n ingress-nginx get svc nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Access app at: http://$INGRESS_IP"
```

### Step 4: Apply Horizontal Pod Autoscaler (HPA)
HPA automatically scales pod replicas based on memory utilization (50% target).

```bash
kubectl apply -f hpa.yaml
```

Verify HPA configuration:
```bash
kubectl get hpa
kubectl describe hpa little-lemon-hpa
```

Initially, HPA shows `<unknown>` for current usage while metrics are being collected (takes 1-2 minutes):
```bash
kubectl get hpa -w  # watch for metrics to appear
```

### Step 5: Install Datadog Monitoring Agent

#### 5a) Create Datadog API Key Secret
First, get your API key from Datadog UI (https://app.datadoghq.com -> Integrations -> APIs -> API Keys).

Create Kubernetes secret with your key:
```bash
kubectl create namespace datadog || true

# Replace <YOUR_DATADOG_API_KEY> with actual key from Datadog UI
kubectl create secret generic datadog-api \
  --from-literal=api-key='<YOUR_DATADOG_API_KEY>' \
  -n datadog
```

Alternative: Edit `k8s/datadog-secret.yaml` with your actual API key, then:
```bash
kubectl apply -f datadog-secret.yaml
```

#### 5b) Install Datadog Agent via Helm
```bash
helm repo add datadog https://helm.datadoghq.com
helm repo update

# Install using values file and existing secret
helm install datadog-agent datadog/datadog \
  -f datadog-values.yaml \
  --namespace datadog
```

Verify installation:
```bash
kubectl -n datadog get pods
kubectl -n datadog logs -l app=datadog-agent -f  # check agent logs
```

#### 5c) Create Dashboards and Alerts in Datadog UI
After agent starts reporting metrics (~2-3 minutes), open Datadog UI:

1. **Go to Dashboards**:
   - Create a new Dashboard
   - Add widgets for:
     - `kubernetes.memory.usage` (sum by host)
     - `kubernetes.cpu.usage` (avg by host)
     - `kubernetes_state.container.memory_usage` (for pod memory)
     - `kubernetes_state.container.cpu_usage` (for pod CPU)

2. **Create Monitors (Alerts)**:
   - Condition: if `kubernetes_state.container.memory_usage` > 256MB for 2+ minutes
   - Action: Send to your email or Slack channel
   - Repeat for CPU, node status, etc.

3. **Tag metrics**:
   - Add tags in the Helm values or Datadog UI to group by environment, cluster, etc.

### Step 6: Test HPA Scaling by Generating Load

Start a load-generator pod that continuously hits your app:
```bash
kubectl run -i --tty load-generator --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://little-lemon-service.default.svc.cluster.local:80/; done"
```

In another terminal, watch HPA and deployment scale:
```bash
kubectl get hpa -w
# or
kubectl get deploy -w
# or
kubectl top pods  # if metrics-server is working
```

Expected behavior:
- Memory usage increases as load-generator hits the app
- HPA triggers and scales replicas from 1 to 2, 3, 4, 5 (up to maxReplicas: 5)
- When you stop load-generator, usage drops and HPA scales down

Stop load-generator when done:
- In the first terminal: Press `Ctrl+C`
- Then delete the pod:
  ```bash
  kubectl delete pod load-generator
  ```

### Step 7: Verify Full Stack is Working

```bash
# Check all components are running
kubectl get all -A | grep -E "little-lemon|nginx|datadog|metrics-server"

# Pod details
kubectl get pods -o wide

# HPA status
kubectl get hpa
kubectl describe hpa little-lemon-hpa

# Ingress status
kubectl get ingress
kubectl describe ingress little-lemon-ingress

# Datadog agent status
kubectl -n datadog get pods

# Test app endpoint
curl -I http://<EXTERNAL-IP>/
curl -I http://<EXTERNAL-IP>/static/css/style.css

# View logs
kubectl logs -l app=little-lemon -f
```

## Cleanup (Tear Down Everything)

```bash
# Delete app and HPA
kubectl delete -f django-deployment.yaml
kubectl delete -f django-service.yaml
kubectl delete -f nginx-ingress.yaml
kubectl delete -f hpa.yaml

# Uninstall Helm releases
helm uninstall nginx-ingress -n ingress-nginx
helm uninstall datadog-agent -n datadog
kubectl delete namespace ingress-nginx datadog

# Delete metrics-server
kubectl delete -f metrics-server.yaml
```

## Troubleshooting

### HPA shows `<unknown>` metrics
- Metrics Server not running: `kubectl -n kube-system get pods | grep metrics-server`
- Pod lacks resource requests: Check `kubectl describe pod <pod>` has `requests: {cpu, memory}`
- Wait 2-3 minutes for metrics collection

### Ingress EXTERNAL-IP stays pending
- Check NLB provisioning in AWS EC2 -> Load Balancers
- Verify security groups allow inbound traffic on port 80/443
- Check Nginx controller logs: `kubectl -n ingress-nginx logs -l app.kubernetes.io/name=ingress-nginx`

### Datadog agent not reporting metrics
- Check secret exists: `kubectl -n datadog get secret datadog-api`
- Check agent logs: `kubectl -n datadog logs -l app=datadog-agent`
- Verify API key is correct (not expired or revoked)
- Check Datadog UI -> Infrastructure -> Hosts for your cluster appearing

### Pod CrashLooping or not starting
- Check logs: `kubectl logs <pod-name>`
- Check events: `kubectl describe pod <pod-name>`
- Verify image is accessible: `docker pull keroles149/little-lemon:latest`
- Check resource availability: `kubectl describe nodes`

## File Reference

```
k8s/
├── README.md (this file)
├── metrics-server.yaml          # Metrics server deployment
├── django-deployment.yaml       # Django app deployment (resource limits, probes)
├── django-service.yaml          # Internal service
├── nginx-ingress.yaml           # Ingress resource (routes to Django)
├── nginx-ingress-install.sh     # Helm install command for Nginx
├── hpa.yaml                     # HPA definition (memory-based scaling)
├── datadog-secret.yaml          # K8s secret template for Datadog API key
├── datadog-values.yaml          # Helm values for Datadog agent
└── datadog-install.sh           # Datadog install script
```

## Architecture Diagram

```
Internet
    ↓
AWS NLB (Network Load Balancer) [Nginx Ingress Controller]
    ↓
Nginx Ingress Pod (ingress-nginx namespace)
    ↓
little-lemon-service (ClusterIP)
    ↓
little-lemon Pod(s) (scaled by HPA based on memory)
    ↓
Datadog Agent (collects metrics)
    ↓
Metrics Server (collects CPU/Memory metrics)
    ↓
Datadog Cloud (monitoring dashboard & alerts)
```

## Summary: Task Completion Checklist

- [x] EKS Cluster Setup: Created via Terraform (`../terraform/`)
- [x] Deploy Sample Application: Django app deployed with resource limits & health probes
- [x] Ingress Controller: Nginx Ingress installed and Ingress resource applied
- [x] HPA: Memory-based HPA (50% utilization target) applied
- [x] Monitoring (Datadog): Agent installed, dashboards/alerts created in UI
- [x] Documentation: This README with all step-by-step commands
