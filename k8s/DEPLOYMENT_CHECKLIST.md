# Deployment Checklist & Verification Guide

## Pre-Deployment Checklist

- [ ] EKS cluster created (Terraform in `../terraform/`)
- [ ] `kubectl` configured: `aws eks update-kubeconfig --region us-east-1 --name little-lemon-cluster`
- [ ] `helm` installed: `helm version`
- [ ] Datadog account created and API key obtained from UI
- [ ] Docker image pushed to registry (`keroles149/little-lemon:latest` is public)

## Deployment Steps & Verification

### Step 1: Cluster Access
- [ ] Run: `kubectl get nodes -o wide` → shows 2 Ready nodes
- [ ] Run: `kubectl get pods -A | head -n 20` → shows system pods

### Step 2: Metrics Server
- [ ] Run: `kubectl apply -f metrics-server.yaml`
- [ ] Verify: `kubectl -n kube-system get pods | grep metrics-server` → shows 1 Running pod
- [ ] Check: `kubectl -n kube-system logs -l k8s-app=metrics-server | head -n 20` → no errors

### Step 3: Django Deployment
- [ ] Run: `kubectl apply -f django-deployment.yaml` and `kubectl apply -f django-service.yaml`
- [ ] Verify: `kubectl get pods` → `little-lemon-*` pod shows 1/1 Running
- [ ] Check: `kubectl logs pod/$(kubectl get pods -o name | grep little-lemon | cut -d/ -f2)` → no errors
- [ ] Verify service: `kubectl get svc little-lemon-service` → shows ClusterIP

### Step 4: Nginx Ingress
- [ ] Run Helm install commands from README (Step 3)
- [ ] Run: `kubectl apply -f nginx-ingress.yaml`
- [ ] Verify: `kubectl -n ingress-nginx get pods | grep controller` → shows 1 Running pod
- [ ] Check: `kubectl -n ingress-nginx get svc` → `nginx-ingress-ingress-nginx-controller` shows EXTERNAL-IP (NLB hostname)
- [ ] Test: `curl -I http://<EXTERNAL-IP>/` → HTTP 200 OK

### Step 5: HPA Setup
- [ ] Run: `kubectl apply -f hpa.yaml`
- [ ] Verify: `kubectl get hpa` → shows `little-lemon-hpa`
- [ ] Check: `kubectl describe hpa little-lemon-hpa` → shows target memory utilization 50%
- [ ] Wait: `kubectl get hpa -w` → until `TARGETS` shows a value like `<5%>` (not `<unknown>`)

### Step 6: Datadog Agent
- [ ] Create secret: `kubectl create secret generic datadog-api --from-literal=api-key='<KEY>' -n datadog`
- [ ] Verify secret: `kubectl -n datadog get secret datadog-api`
- [ ] Run Helm install: see README Step 5b
- [ ] Verify: `kubectl -n datadog get pods` → agent and cluster-agent pods show Running
- [ ] Check logs: `kubectl -n datadog logs -l app=datadog-agent | head -n 30` → should show connection to Datadog

### Step 7: Datadog Dashboards & Alerts
- [ ] Open: https://app.datadoghq.com (or .eu)
- [ ] Check: Infrastructure → Hosts → cluster should appear
- [ ] Create Dashboard: add widgets for memory/CPU metrics (see README Step 5c)
- [ ] Create Monitor (Alert): configure threshold and notification channel

### Step 8: HPA Load Testing
- [ ] Start load-gen: `kubectl run load-gen --image=busybox --restart=Never -- sh -c "while true; do wget -q -O- http://little-lemon-service/; done"`
- [ ] Watch HPA: `kubectl get hpa -w` → replicas should increase from 1 to 2, 3, 4, 5
- [ ] Watch deployment: `kubectl get deploy -w` → DESIRED and CURRENT should match HPA scale
- [ ] Check metrics: `kubectl top pods` → memory usage increases
- [ ] Monitor Datadog: dashboards show increased memory/CPU
- [ ] Stop load: `Ctrl+C` in load-gen terminal, then `kubectl delete pod load-gen`
- [ ] Verify scale-down: `kubectl get hpa -w` → after ~5 min, replicas decrease to 1

## Post-Deployment Verification

### All Resources Running
```bash
kubectl get all -A | grep -E "little-lemon|ingress-nginx|datadog|metrics-server"
```
Expected output should show:
- 2 nodes Ready
- little-lemon pod(s) Running
- nginx-ingress pod Running, service with EXTERNAL-IP
- datadog-agent pods Running
- metrics-server pod Running in kube-system

### Metrics Collection Active
```bash
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes | jq .
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods | jq .
```
Expected: JSON output with node and pod CPU/memory metrics (not empty)

### Datadog Receiving Data
In Datadog UI:
- [ ] Infrastructure → Hosts → your cluster hostname appears
- [ ] Dashboards → metrics show data (not `No data`)
- [ ] Monitors → check status is `OK` or triggering as expected

### App Accessibility
```bash
EXTERNAL_IP=$(kubectl -n ingress-nginx get svc nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -v http://$EXTERNAL_IP/
curl -I http://$EXTERNAL_IP/static/css/style.css
```
Expected: HTTP 200, CSS/static files load correctly

## Troubleshooting

### Metrics server not running
```bash
kubectl -n kube-system describe pod -l k8s-app=metrics-server
kubectl -n kube-system logs -l k8s-app=metrics-server
```
Check for permission/image pull errors.

### Ingress EXTERNAL-IP pending after 5+ minutes
```bash
kubectl -n ingress-nginx describe svc nginx-ingress-ingress-nginx-controller
kubectl -n ingress-nginx logs -l app.kubernetes.io/name=ingress-nginx
```
Check AWS console for NLB provisioning errors, security group issues.

### HPA shows <unknown> for metrics
- Metrics server not running: see above
- Pod missing resource requests: `kubectl describe pod <pod>` check for `requests: {cpu: 100m, memory: 128Mi}`
- Wait 2-3 minutes for metrics collection: `kubectl top nodes`

### Datadog agent not reporting
```bash
kubectl -n datadog logs -l app=datadog-agent
kubectl -n datadog describe secret datadog-api
kubectl -n datadog get env pod/datadog-agent-* | grep DD_API_KEY
```
Verify API key is correct and not expired.

### Pod not starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```
Check Events section for errors (ImagePullBackOff, Pending, OOMKilled, etc.)

## Cleanup & Teardown

To completely remove all resources (WARNING: irreversible):
```bash
# Delete app and HPA
kubectl delete -f django-deployment.yaml
kubectl delete -f django-service.yaml
kubectl delete -f nginx-ingress.yaml
kubectl delete -f hpa.yaml

# Uninstall Helm releases
helm uninstall nginx-ingress -n ingress-nginx
helm uninstall datadog-agent -n datadog

# Delete namespaces
kubectl delete namespace ingress-nginx datadog

# Delete metrics-server
kubectl delete -f metrics-server.yaml
```

To delete the EKS cluster entirely (destroys all resources):
```bash
cd ../terraform
terraform destroy
```

## Success Criteria Met

- [x] EKS Cluster: Created and nodes are Ready
- [x] Deployment: Django app running with resource limits and health probes
- [x] Ingress: Nginx Ingress installed, external IP assigned, traffic routed
- [x] HPA: Memory-based autoscaler active, scales up under load, scales down when idle
- [x] Monitoring: Datadog agent collecting metrics, dashboards displaying data, alerts configured
- [x] Documentation: Complete README and this checklist
