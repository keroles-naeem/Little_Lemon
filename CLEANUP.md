# Complete Cleanup & Teardown Guide

This guide covers removing all Little Lemon resources from your EKS cluster and AWS account in stages, from least destructive to complete removal.

## Cleanup Levels (Choose One)

### Level 1: Remove App Only (Keep Cluster Running)
Removes the Django app, Ingress, HPA, and monitoring agent. Keeps EKS cluster, nodes, and infrastructure intact. **Useful for redeployment or testing.**

```bash
cd k8s
chmod +x cleanup-k8s.sh
./cleanup-k8s.sh
```

This removes:
- Django deployment and service
- Nginx Ingress controller and Ingress resource
- HPA
- Datadog agent
- Metrics server

The EKS cluster and nodes remain. You can redeploy the app using `./deploy-all.sh`.

### Level 2: Manual Removal (Step-by-Step)

If you prefer to remove resources manually:

#### 2a) Remove app and ingress
```bash
cd k8s
kubectl delete -f django-deployment.yaml
kubectl delete -f django-service.yaml
kubectl delete -f nginx-ingress.yaml
```

#### 2b) Remove HPA
```bash
kubectl delete -f hpa.yaml
```

#### 2c) Uninstall Helm releases
```bash
# Nginx Ingress
helm uninstall nginx-ingress -n ingress-nginx
kubectl delete namespace ingress-nginx

# Datadog
helm uninstall datadog-agent -n datadog
kubectl delete secret datadog-api -n datadog
kubectl delete namespace datadog
```

#### 2d) Remove metrics-server
```bash
kubectl delete -f metrics-server.yaml
```

#### 2e) Verify cleanup
```bash
kubectl get all -A
kubectl get pvc -A
kubectl get pv -A
```

### Level 3: Destroy EKS Cluster (Keep AWS Account)
Removes the entire EKS cluster, VPC, nodes, and all AWS infrastructure. **AWS account remains; you can create new clusters.**

**Option A: Using the cleanup script (recommended)**
```bash
cd terraform
chmod +x cleanup-terraform.sh
./cleanup-terraform.sh
```

**Option B: Manual Terraform destroy**
```bash
cd terraform
terraform plan -destroy
terraform apply
# or
terraform destroy
```

Terraform will prompt for confirmation before destroying resources.

### Level 4: Complete Cleanup (All K8s + AWS)
Remove everything: app, cluster, and infrastructure.

```bash
# Step 1: Remove K8s app resources
cd k8s
./cleanup-k8s.sh

# Step 2: Destroy AWS infrastructure
cd ../terraform
./cleanup-terraform.sh
```

## What Gets Deleted at Each Level

| Resource | Level 1 | Level 3 | Level 4 |
|----------|---------|---------|---------|
| Django Deployment | ✓ | ✓ | ✓ |
| Services/Ingress | ✓ | ✓ | ✓ |
| HPA | ✓ | ✓ | ✓ |
| Metrics Server | ✓ | ✓ | ✓ |
| Datadog Agent | ✓ | ✓ | ✓ |
| EKS Cluster | - | ✓ | ✓ |
| VPC/Subnets | - | ✓ | ✓ |
| NAT Gateways | - | ✓ | ✓ |
| IAM Roles | - | ✓ | ✓ |
| Elastic IPs | - | ✓ | ✓ |
| AWS Account | - | - | - |

## Cost Implications

**With cluster running**: ~$560–650/month (EKS control plane, NLB, NAT gateways, EC2 nodes)
**After Level 1 cleanup**: ~$560–650/month (cluster still running, no app costs)
**After Level 3 cleanup**: ~$0/month (cluster destroyed, no charges for resources)

## Verification Steps

### After Level 1 (App removed, cluster running)
```bash
# Should see empty/minimal app pods
kubectl get all -n default
# Cluster should still exist
kubectl get nodes
```

### After Level 3 (Cluster destroyed)
```bash
# EKS cluster should not appear
aws eks list-clusters --region us-east-1

# VPC should be deleted or empty
aws ec2 describe-vpcs --region us-east-1 | grep little-lemon || echo "VPC removed"

# No NLB should remain
aws elbv2 describe-load-balancers --region us-east-1 | grep -i little-lemon || echo "NLBs removed"
```

## Important Notes

### Irreversible Operations
- **Level 3 and 4 are PERMANENT**. Once Terraform destroy completes, resources are gone and cannot be recovered (unless you have backups/snapshots).
- EBS volumes created by the cluster may be retained; check AWS console and delete manually if needed.
- Snapshots of old data are not automatically deleted.

### Before Destroying
1. **Backup data**: Export any important data from the database (`db.sqlite3`), logs, or configs.
2. **Check AWS console**: Verify no critical resources are attached (e.g., if you manually created resources in that VPC).
3. **Verify Terraform state**: Ensure `terraform/terraform.tfstate` is in sync with actual AWS resources.

### If Destroy Fails
- Check the error message; often it's due to resources being in use or permission issues.
- Manually delete blocking resources in AWS console (e.g., security groups with dependencies).
- Re-run `terraform destroy` after cleanup.

Example troubleshooting:
```bash
# Identify resources causing issues
terraform plan -destroy

# If a resource is stuck, check AWS console or use AWS CLI
aws ec2 describe-network-interfaces --region us-east-1 | grep -i little-lemon

# Manually delete via AWS CLI if needed
aws ec2 delete-network-interface --network-interface-id <eni-id> --region us-east-1
```

## Redeploying After Cleanup

### After Level 1 (App only)
Simply redeploy:
```bash
cd k8s
export DATADOG_API_KEY="<YOUR_KEY>"
./deploy-all.sh
```

### After Level 3 (Cluster destroyed)
Recreate the cluster:
```bash
cd terraform
terraform apply
aws eks update-kubeconfig --region us-east-1 --name little-lemon-cluster
cd ../k8s
export DATADOG_API_KEY="<YOUR_KEY>"
./deploy-all.sh
```

## Safety Checklist

Before running cleanup, verify:

- [ ] All important data is backed up
- [ ] No critical workloads depend on this cluster
- [ ] You understand the cost impact of destroying resources
- [ ] You have AWS permissions to delete resources (EC2, EKS, IAM, VPC)
- [ ] You're in the correct AWS account (check `aws sts get-caller-identity`)

## Troubleshooting Cleanup Failures

### Script not found
```bash
chmod +x cleanup-k8s.sh
chmod +x ../terraform/cleanup-terraform.sh
```

### Namespace stuck in Terminating
```bash
# Force delete a stuck namespace
kubectl delete namespace <namespace> --grace-period=0 --force
```

### Helm release uninstall fails
```bash
# List Helm releases
helm list -a --all-namespaces

# Force delete a release
helm delete <release-name> --namespace <namespace> --force
```

### Terraform destroy hangs or fails
```bash
# Check Terraform state
terraform state list

# Manually mark resource as destroyed in state (use with caution)
terraform state rm <resource_name>

# Re-run destroy
terraform destroy
```

### AWS resources remain after cleanup
Check AWS Console:
- EC2 → Instances: manually terminate any EC2 instances
- EC2 → Load Balancers: delete any NLBs
- EC2 → Security Groups: delete custom security groups
- VPC → VPCs: delete custom VPCs
- IAM → Roles: delete IAM roles created by cluster

## Final Cleanup Steps (If Needed)

After `terraform destroy`, manually verify and remove any lingering resources:

```bash
# List all EC2 resources in the region
aws ec2 describe-instances --region us-east-1 --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table

# Delete specific resources if needed
aws ec2 terminate-instances --instance-ids <i-xxx> --region us-east-1
aws elbv2 delete-load-balancer --load-balancer-arn <arn> --region us-east-1
aws ec2 delete-security-group --group-id <sg-xxx> --region us-east-1
```

## Summary

| Action | Command | Time | Cost Impact |
|--------|---------|------|------------|
| Remove app only | `./cleanup-k8s.sh` | ~2 min | Cluster still costs ~$560/mo |
| Destroy cluster | `terraform destroy` | ~10–15 min | $0/mo (no charges) |
| Full cleanup | Both scripts | ~15–20 min | $0/mo |

Choose the level that matches your needs. Start with Level 1 if unsure.
