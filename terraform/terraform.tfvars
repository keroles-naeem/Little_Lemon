# Override defaults for a slightly larger node pool
aws_region      = "us-east-1"
cluster_name    = "little-lemon-cluster"
# Use a slightly bigger instance so pods can schedule reliably
instance_type   = "t3.small"
# Start with 2 nodes for capacity
desired_size    = 2
min_size        = 1
max_size        = 3

# Kubernetes version can be adjusted if needed
# kubernetes_version = "1.34"
