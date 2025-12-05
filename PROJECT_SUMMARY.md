# Little Lemon - Django + Kubernetes + Monitoring Project

**Status**: ✅ Complete - Production-ready EKS deployment with monitoring

## Project Overview

Little Lemon is a full-stack Django restaurant application deployed on AWS EKS with Kubernetes best practices, auto-scaling, and enterprise-grade monitoring.

## What's Included

### 1. Django Application
- **Framework**: Django 5.0.7 with WhiteNoise for static file serving
- **Database**: SQLite (can be upgraded to PostgreSQL)
- **Features**: 
  - Restaurant menu management
  - Online booking system
  - Static CSS/images optimized for production
  - Multi-page templates (index, menu, about, booking)

**Key Files**:
- `manage.py` - Django management script
- `littlelemon/` - Project settings, WSGI, ASGI
- `restaurant/` - App with models, views, templates, static files
- `requirements.txt` - Python dependencies

### 2. Docker Containerization
- **Image**: `keroles149/little-lemon:latest` (publicly available on Docker Hub)
- **Dockerfile**: Multi-stage build, includes WhiteNoise for static serving
- **Entry Point**: Gunicorn web server + automatic migrations & collectstatic

**Key Files**:
- `Dockerfile` - Container image definition
- `entrypoint.sh` - Container startup script with migrations

### 3. AWS EKS Infrastructure (Terraform)

Complete Infrastructure-as-Code for AWS EKS cluster with networking, security, and auto-scaling.

**Included**:
- **VPC**: Custom VPC with 2 public + 2 private subnets across 2 AZs
- **EKS Cluster**: Kubernetes 1.34, managed control plane
- **Node Group**: Auto-scaling group (1-3 nodes, t3.small instances)
- **NAT Gateways**: High-availability outbound traffic
- **Security Groups**: Cluster + node communication properly configured
- **IAM Roles**: EKS cluster + worker node roles with necessary permissions
- **OIDC Provider**: For IRSA (IAM Roles for Service Accounts)

**Key Files**:
- `terraform/` - Infrastructure code
  - `main.tf` - VPC, EKS, node groups, security groups, IAM
  - `variables.tf` - Configurable parameters
  - `terraform.tfvars` - Environment-specific values
  - `outputs.tf` - Cluster endpoint, kubeconfig command
  - `README.md` - Deployment instructions

**Deployment**:
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Kubernetes Manifests & Deployment

**Core Stack**:
- Django deployment with resource limits, health probes, and environment variables
- ClusterIP service for internal routing
- Nginx Ingress Controller (NLB-backed) for external access
- Horizontal Pod Autoscaler (HPA) based on memory utilization (50% target)
- Metrics Server for CPU/memory metrics

**Key Files**:
- `k8s/django-deployment.yaml` - App deployment (1+ pods, auto-scaling)
- `k8s/django-service.yaml` - Internal service
- `k8s/nginx-ingress.yaml` - Ingress resource (routes to Django)
- `k8s/hpa.yaml` - Auto-scaling config (1-5 replicas, memory-based)
- `k8s/metrics-server.yaml` - Metrics collection for HPA
- `k8s/README.md` - Detailed K8s deployment guide

**Monitoring**:
- Datadog agent for cluster & application monitoring
- Configurable dashboards and alerts in Datadog UI
- Custom metrics collection via Prometheus

**Key Files**:
- `k8s/datadog-values.yaml` - Helm chart values for Datadog
- `k8s/datadog-secret.yaml` - API key secret template
- `k8s/DEPLOYMENT_CHECKLIST.md` - Pre/post-deployment verification

### 5. Deployment Scripts

**Quick Deploy**:
- `k8s/deploy-all.sh` - Full stack: metrics-server → Django → Nginx → HPA → Datadog
- `k8s/deploy-core.sh` - Core stack only (no Datadog, faster for testing)

**Cleanup**:
- `k8s/cleanup-k8s.sh` - Remove all K8s resources, keep cluster running
- `terraform/cleanup-terraform.sh` - Destroy entire AWS infrastructure
- `cleanup-project.sh` - Remove Python cache, temp files, duplicates
- `CLEANUP.md` - Comprehensive cleanup guide with cost implications

### 6. Documentation

- **`terraform/README.md`** - Terraform setup and AWS infrastructure
- **`k8s/README.md`** - Kubernetes deployment, HPA, Datadog integration
- **`k8s/DEPLOYMENT_CHECKLIST.md`** - Step-by-step verification guide
- **`CLEANUP.md`** - Cleanup procedures and troubleshooting
- **`README.md`** - Project overview (this file)

## Quick Start

### Prerequisites
- AWS account with permissions (EC2, EKS, VPC, IAM)
- `terraform` >= 1.0
- `kubectl` configured
- `helm` 3.x installed
- Datadog account (optional)

### Deploy (One Command)
```bash
# Step 1: Create AWS infrastructure
cd terraform
terraform init
terraform apply

# Step 2: Deploy Kubernetes stack
cd ../k8s
export DATADOG_API_KEY="<YOUR_DATADOG_API_KEY>"
chmod +x deploy-all.sh
./deploy-all.sh
```

### Access Application
```bash
# Get NLB external IP
EXTERNAL_IP=$(kubectl -n ingress-nginx get svc nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$EXTERNAL_IP
```

### Test Auto-Scaling
```bash
# Generate load
kubectl run load-gen --image=busybox --restart=Never -- sh -c "while true; do wget -q -O- http://little-lemon-service/; done"

# Watch HPA scale pods
kubectl get hpa -w

# When done, stop load
kubectl delete pod load-gen
```

## Architecture

```
Internet
   ↓
AWS Network Load Balancer (NLB)
   ↓
Nginx Ingress Controller Pod (port 80/443)
   ↓
Django Service (ClusterIP, internal)
   ↓
Django App Pods (1-5 replicas, auto-scaled by HPA)
   ↓
Metrics Server (collects CPU/memory for HPA)
   ↓
Datadog Agent (optional, sends metrics to Datadog cloud)
```

## Kubernetes Components

| Component | Purpose | Status |
|-----------|---------|--------|
| **Metrics Server** | Collects pod/node metrics for HPA | ✅ Deployed |
| **Django Deployment** | App pods with resource limits & probes | ✅ Deployed |
| **Service** | Internal routing to pods | ✅ Deployed |
| **Nginx Ingress** | External traffic routing (NLB) | ✅ Deployed |
| **HPA** | Auto-scales pods based on memory | ✅ Deployed |
| **Datadog Agent** | Cluster & app monitoring | ✅ Deployed |

## Resource Limits & Requests

Django Pod:
- **Requests**: 100m CPU, 128Mi memory
- **Limits**: 500m CPU, 512Mi memory

HPA Target: 50% memory utilization

This ensures stable performance and predictable auto-scaling behavior.

## Monitoring & Observability

**Metrics Available**:
- Pod CPU/memory usage
- Node resource utilization
- Container restart count
- Ingress request counts (via Nginx)
- Custom app metrics (via Datadog)

**Datadog Features** (if configured):
- Live dashboards showing cluster health
- Alerts for high memory/CPU, node failures
- Log aggregation from containers
- Trace collection (APM ready)

## Cleanup & Cost Management

**Estimated Monthly Costs**:
- EKS Control Plane: ~$73
- t3.small EC2 (2 nodes): ~$15
- NAT Gateways (2×): ~$32
- NLB: ~$18
- **Total**: ~$140/month (varies by region)

**To reduce costs**:
1. Use `t3.nano` instead of `t3.small` (save ~$7/node)
2. Use single NAT gateway (save ~$15/month)
3. Use spot instances (save ~40%)
4. Delete cluster when not in use: `terraform destroy`

See `CLEANUP.md` for detailed cleanup procedures.

## Security Best Practices Implemented

- ✅ Private subnets for worker nodes
- ✅ Security groups restrict traffic to necessary ports
- ✅ IAM roles with least-privilege policies
- ✅ OIDC provider for IRSA (IAM for Service Accounts)
- ✅ WhiteNoise for static file serving (no directory listing)
- ✅ Django DEBUG=False in production
- ✅ Resource limits prevent resource exhaustion attacks
- ✅ Health probes ensure pod liveness

## File Structure

```
Little_Lemon/
├── Dockerfile                 # Container image definition
├── entrypoint.sh             # Container startup script
├── manage.py                 # Django CLI
├── requirements.txt          # Python dependencies
├── Pipfile                   # Pipenv lockfile
├── db.sqlite3               # SQLite database (local dev only)
├── .gitignore               # Git ignore rules
├── README.md                # This file
├── CLEANUP.md               # Cleanup procedures
├── cleanup-project.sh       # Project cleanup script
│
├── littlelemon/             # Django project settings
│   ├── settings.py          # Django configuration (DEBUG=False in deploy)
│   ├── urls.py
│   ├── asgi.py
│   ├── wsgi.py
│   └── __init__.py
│
├── restaurant/              # Django app
│   ├── models.py            # Database models
│   ├── views.py             # View logic
│   ├── urls.py              # URL routing
│   ├── admin.py             # Admin panel config
│   ├── templates/           # HTML templates
│   │   ├── base.html
│   │   ├── index.html
│   │   ├── menu.html
│   │   ├── about.html
│   │   ├── book.html
│   │   └── partials/
│   └── static/              # CSS, JS, images
│       ├── css/style.css
│       └── img/menu_items/
│
├── terraform/               # AWS Infrastructure as Code
│   ├── main.tf              # VPC, EKS, nodes, security, IAM
│   ├── variables.tf         # Input variables
│   ├── terraform.tfvars     # Variable values (override defaults)
│   ├── outputs.tf           # Output values (cluster endpoint, etc.)
│   ├── README.md            # Terraform usage guide
│   ├── cleanup-terraform.sh # Destroy AWS resources
│   └── .gitignore           # Ignore Terraform state files
│
├── k8s/                     # Kubernetes manifests & scripts
│   ├── README.md            # K8s deployment guide
│   ├── DEPLOYMENT_CHECKLIST.md
│   ├── metrics-server.yaml  # Metrics collection for HPA
│   ├── django-deployment.yaml
│   ├── django-service.yaml
│   ├── nginx-ingress.yaml   # Ingress routing
│   ├── hpa.yaml             # Auto-scaling
│   ├── datadog-values.yaml  # Datadog Helm values
│   ├── datadog-secret.yaml  # API key template
│   ├── deploy-all.sh        # Deploy full stack
│   ├── deploy-core.sh       # Deploy core (no Datadog)
│   ├── cleanup-k8s.sh       # Remove K8s resources
│   └── nginx-ingress-install.sh (deprecated, use deploy-all.sh)
│
└── django-deployment.yaml   # K8s deployment (root, symlinked or copied)
└── django-service.yaml      # K8s service (root, symlinked or copied)
```

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### HPA not scaling
```bash
# Check metrics are available
kubectl top nodes
kubectl top pods
```

### Ingress EXTERNAL-IP pending
```bash
kubectl -n ingress-nginx describe svc nginx-ingress-ingress-nginx-controller
```

### Datadog agent not reporting
```bash
kubectl -n datadog logs -l app=datadog-agent | head -20
```

See `k8s/README.md` and `DEPLOYMENT_CHECKLIST.md` for detailed troubleshooting.

## Next Steps / Production Enhancements

- [ ] Add PostgreSQL RDS for production database
- [ ] Configure TLS/SSL with cert-manager
- [ ] Set up CI/CD pipeline (GitHub Actions, GitLab CI)
- [ ] Add Kubernetes network policies for security
- [ ] Set up cluster autoscaling (Karpenter or CA)
- [ ] Enable pod disruption budgets (PDB)
- [ ] Configure backup strategy for EBS volumes
- [ ] Add log aggregation (ELK stack or CloudWatch)
- [ ] Implement RBAC with service accounts
- [ ] Set up Kubernetes audit logging

## Support & Documentation

- **Terraform**: See `terraform/README.md`
- **Kubernetes**: See `k8s/README.md`
- **Cleanup**: See `CLEANUP.md`
- **Deployment Checklist**: See `k8s/DEPLOYMENT_CHECKLIST.md`
- **AWS EKS Docs**: https://docs.aws.amazon.com/eks/
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **Datadog Docs**: https://docs.datadoghq.com/

## License & Credits

- Django: Web framework
- Kubernetes: Container orchestration
- AWS EKS: Managed Kubernetes service
- Datadog: Monitoring platform
- Terraform: Infrastructure as Code

---

**Last Updated**: December 5, 2025  
**Status**: ✅ Production Ready  
**Maintained By**: keroles-naeem  
**Repository**: https://github.com/keroles-naeem/Little_Lemon
