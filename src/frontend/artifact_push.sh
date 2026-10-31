#!/bin/bash
set -euo pipefail

REPO_NAME="$1"
REGION="$2"
USER_POOL_ID="${3:-${VITE_COGNITO_USER_POOL_ID:-}}"
CLIENT_ID="${4:-${VITE_COGNITO_CLIENT_ID:-}}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${DIR}"

echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "Building Frontend Docker Image..."
docker build \
  --build-arg VITE_AWS_REGION="${REGION}" \
  --build-arg VITE_COGNITO_USER_POOL_ID="${USER_POOL_ID}" \
  --build-arg VITE_COGNITO_CLIENT_ID="${CLIENT_ID}" \
  --build-arg VITE_API_BASE_URL="" \
  -t "${ECR_URI}:latest" .

echo "Pushing image to ${ECR_URI}:latest..."
docker push "${ECR_URI}:latest"
echo "Frontend push complete."
