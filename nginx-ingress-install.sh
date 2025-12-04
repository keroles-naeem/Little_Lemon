# Nginx Ingress Controller using Helm
# This file documents the commands to install Nginx Ingress on your EKS cluster

# Step 1: Add the Nginx Helm repository
# helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# helm repo update

# Step 2: Create namespace for Nginx Ingress
# kubectl create namespace ingress-nginx

# Step 3: Install Nginx Ingress Controller
# helm install nginx-ingress ingress-nginx/ingress-nginx \
#   --namespace ingress-nginx \
#   --set controller.service.type=LoadBalancer \
#   --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb"

# After installation, get the external IP/hostname:
# kubectl get svc -n ingress-nginx
# Look for nginx-ingress-ingress-nginx-controller with EXTERNAL-IP

# Quick one-liner to install all at once:
# helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && \
# helm repo update && \
# kubectl create namespace ingress-nginx && \
# helm install nginx-ingress ingress-nginx/ingress-nginx \
#   --namespace ingress-nginx \
#   --set controller.service.type=LoadBalancer \
#   --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb"
