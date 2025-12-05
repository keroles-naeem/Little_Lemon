#!/bin/bash
# cleanup-project.sh - Remove unnecessary/duplicate files from the project
# Usage: ./cleanup-project.sh

echo "========================================="
echo "Little Lemon Project Cleanup"
echo "========================================="

# Remove duplicate scripts
echo "[1/3] Removing duplicate/old scripts..."
rm -f k8s/entrypoint.sh 2>/dev/null || true
rm -f k8s/datadog-install.sh 2>/dev/null || true
rm -f k8s/nginx-ingress-install.sh 2>/dev/null || true
echo "Done."

# Remove Python cache
echo "[2/3] Cleaning Python cache..."
find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true
find . -type d -name ".pytest_cache__" -exec rm -rf {} + 2>/dev/null || true
echo "Done."

# Remove temporary files
echo "[3/3] Cleaning temporary files..."
rm -f *.tmp 2>/dev/null || true
rm -f .DS_Store 2>/dev/null || true
rm -rf .vscode/ 2>/dev/null || true
echo "Done."

echo ""
echo "========================================="
echo "Cleanup complete!"
echo "========================================="
echo ""
echo "Project structure:"
ls -la | grep -v "^\."
echo ""
echo "K8s files:"
ls -la k8s/
echo ""
echo "Ready for Git commit!"
