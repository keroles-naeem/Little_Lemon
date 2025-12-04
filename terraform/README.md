# Little Lemon EKS Cluster (Terraform)

A minimal, cost-effective EKS cluster for deploying the Little Lemon app.

## Features

- **VPC with public & private subnets** across 2 availability zones
- **EKS Control Plane** (managed by AWS)
- **Worker Node Group**: 1 `t3.micro` node (scales to max 2)
- **NAT Gateways** for private subnet egress
- **OIDC Provider** for IAM Roles for Service Accounts (IRSA)
- **Security Groups** properly configured for cluster communication

## Prerequisites

1. **AWS Account** with sufficient permissions
2. **Terraform** >= 1.0 installed
3. **AWS CLI** configured with credentials
4. **kubectl** installed (for managing the cluster post-deployment)

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

This shows all resources that will be created (VPC, subnets, EKS cluster, node group, IAM roles, etc.).

### 3. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted. Cluster creation takes ~10–15 minutes.

### 4. Configure kubectl

After provisioning completes, Terraform will output a command to configure `kubectl`:

```bash
aws eks update-kubeconfig --region us-east-1 --name little-lemon-cluster
```

Copy and run this command (or substitute your region if different).

### 5. Verify Cluster

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

You should see your worker node(s) and system pods.

## Customization

Edit `terraform.tfvars` to override defaults:

```hcl
aws_region      = "us-west-2"           # Change AWS region
cluster_name    = "my-cluster"           # Rename cluster
instance_type   = "t3.small"             # Use t3.small instead of t3.micro
desired_size    = 2                      # Start with 2 nodes
max_size        = 3                      # Allow up to 3 nodes
```

Then run:

```bash
terraform plan
terraform apply
```

## Deploy Your App

Once the cluster is ready, deploy Little Lemon using `kubectl`:

```bash
kubectl create namespace little-lemon

# Update image, add env vars (DEBUG=False), and deploy
kubectl apply -f ../django-deployment.yaml -n little-lemon
kubectl apply -f ../django-service.yaml -n little-lemon

# Check status
kubectl get all -n little-lemon
```

### Scale Nodes

To auto-scale nodes based on CPU/memory demand, install the Kubernetes Autoscaler:

```bash
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update
helm install autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName=little-lemon-cluster \
  --set awsRegion=us-east-1
```

## Cleanup

To destroy all AWS resources:

```bash
terraform destroy
```

Type `yes` to confirm. This removes the EKS cluster, VPC, NAT gateways, and all associated resources.

## Outputs

After `terraform apply`, retrieve key values:

```bash
terraform output cluster_name
terraform output cluster_endpoint
terraform output configure_kubectl
```

## Costs

**Estimated monthly costs** (rough):
- **EKS Control Plane**: ~$0.10/hour = ~$73/month
- **t3.micro EC2 Node**: ~$0.0104/hour = ~$7.50/month
- **NAT Gateway (2×)**: ~$0.32/hour each = ~$478/month total
- **Data Transfer**: Varies; typically $0.02/GB out

**Total**: ~$560–600/month. To reduce costs:
- Use a single NAT Gateway instead of two (edit `main.tf`, remove one)
- Switch to `t3.nano` (less memory, suitable for light workloads)
- Use spot instances (add `capacity_type = "SPOT"` in `aws_eks_node_group`)

## Troubleshooting

### Cluster not becoming ready

Check IAM permissions and VPC routing:

```bash
aws eks describe-cluster --name little-lemon-cluster
```

### Nodes not joining

Verify security group rules allow communication between control plane and nodes:

```bash
aws ec2 describe-security-groups --group-ids <sg-id>
```

### kubectl cannot connect

Ensure the kubeconfig command was run and your AWS credentials are valid:

```bash
aws sts get-caller-identity
```

## Further Reading

- [AWS EKS Docs](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider EKS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster)
- [Kubernetes on AWS Best Practices](https://aws.amazon.com/blogs/containers/amazon-eks-best-practices-guide/)
