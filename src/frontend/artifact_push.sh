#!/bin/bash
set -euo pipefail

REPO_NAME="$1"
REGION="$2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${DIR}"

echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "Building Frontend Docker Image..."
docker build -t "${ECR_URI}:latest" .

echo "Pushing image to ${ECR_URI}:latest..."
docker push "${ECR_URI}:latest"
echo "Frontend push complete."