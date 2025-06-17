#!/bin/bash

# Exit on error
set -e

# Function to load environment variables
load_env() {
  local env_file=$1
  if [ -f "$env_file" ]; then
    echo "Loading environment variables from $env_file..."
    source "$env_file"
  else
    echo "Error: $env_file not found"
    exit 1
  fi
}

# Function to check if this is first deployment
check_first_deployment() {
  echo "Checking if this is first deployment..."
  
  # Check if the app is already deployed
  if fly status > /dev/null 2>&1; then
    echo "App already deployed, not a first deployment"
    return 1
  fi
  
  echo "First deployment detected"
  return 0
}

# Check if environment is specified
if [ "$1" = "prod" ]; then
  echo "Loading production environment..."
  load_env "exports.sh"
else
  echo "Loading development environment..."
  load_env "exports.dev.sh"
fi

# Check if required environment variables are set
required_vars=(
  "STRIPE_SECRET_KEY"
  "STRIPE_PUBLISHABLE_KEY"
  "RESEND_API_KEY"
  "BUCKET_NAME"
  "AWS_ACCESS_KEY_ID"
  "AWS_SECRET_ACCESS_KEY"
  "AWS_REGION"
  "ANTHROPIC_API_KEY"
)

# Check required variables
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Error: $var is not set"
    exit 1
  fi
done

# Check if this is first deployment
IS_FIRST_DEPLOYMENT=false
if check_first_deployment; then
  IS_FIRST_DEPLOYMENT=true
fi

# Launch the application
echo "Launching application on Fly.io..."
fly launch --no-deploy

# Set secrets for production environment
echo "Setting secrets..."
fly secrets set STRIPE_SECRET_KEY="$STRIPE_SECRET_KEY"
fly secrets set STRIPE_PUBLISHABLE_KEY="$STRIPE_PUBLISHABLE_KEY"
fly secrets set RESEND_API_KEY="$RESEND_API_KEY"
fly secrets set BUCKET_NAME="$BUCKET_NAME"
fly secrets set AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
fly secrets set AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
fly secrets set AWS_REGION="$AWS_REGION"
fly secrets set ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"

# Set a flag to indicate if seeding is needed for first deployment
if [ "$IS_FIRST_DEPLOYMENT" = true ]; then
  fly secrets set SEED_DATABASE="true"
  echo "Set SEED_DATABASE flag for first run initialization"
fi

# Deploy the application
echo "Deploying application..."
fly deploy

echo "Deployment completed successfully!"

# Run migrations only (not seeds) for first deployment
if [ "$IS_FIRST_DEPLOYMENT" = true ]; then
  echo "Running initial database migrations..."
  fly ssh console -C "/app/bin/phxplate eval Phxplate.Release.migrate"
  echo "Migrations completed. The app will handle seeding on startup."
fi

echo "Please check the logs for any issues: fly logs" 