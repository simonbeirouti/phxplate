#!/bin/bash

# Resend API Key
export RESEND_API_KEY="rexxx"

# Stripe Keys for Stripity Stripe
export STRIPE_SECRET_KEY="skxxx"
export STRIPE_PUBLISHABLE_KEY="pkxxx"

# S3 Bucket
# Ensure S3 Full access and public access to bucket
export S3_BUCKET="xxxx"
export S3_ACCESS_KEY_ID="xxxx"
export S3_SECRET_ACCESS_KEY="xxxx"
export S3_REGION="xxxx"

echo "Environment variables exported successfully!"
echo "You can now run Phoenix with these environment variables."
