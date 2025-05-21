# Phxplate

## Development Setup

1. Clone the repository and navigate to the project directory

2. Set up your environment variables:
   ```bash
   # Copy the development environment file
   cp export.dev.sh exports.sh
   
   # Edit exports.sh with your values for:
   # - RESEND_API_KEY
   # - STRIPE_SECRET_KEY
   # - STRIPE_PUBLISHABLE_KEY
   # - S3_BUCKET
   # - S3_ACCESS_KEY_ID
   # - S3_SECRET_ACCESS_KEY
   # - S3_REGION
   
   # Load the environment variables
   source exports.sh
   ```

3. Configure basic site features in `config/config.exs`:
   ```elixir
   config :phxplate,
     title: "Your Site Title",
     description: "Your site description",
     base_url: "http://localhost:4000",
     email: "your-email@example.com"
   ```

4. Initial Setup (this will install dependencies and create the database):
   ```bash
   mix setup
   ```
   Note: This command runs:
   - `mix deps.get` - Gets dependencies
   - `mix ecto.setup` - Creates and migrates the database
   - `npm install` - Installs frontend dependencies

5. Database Management:
   ```bash
   # To reset everything (drops and recreates database)
   mix ecto.reset

   # To just drop the database
   mix ecto.drop
   
   # To create and migrate the database
   mix ecto.create
   mix ecto.migrate
   ```

6. Start the Phoenix server:
   ```bash
   mix phx.server
   ```
   Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Testing Environment

For testing purposes, you can populate the database with sample data:
```bash
mix run priv/repo/seeds.exs
```

The seed data can be viewed in `priv/repo/seeds.json`.

## Production Setup

The production environment will automatically:
- Create a super admin account
- Set up three subscription plans (Small, Medium, Large) with both monthly and yearly billing options
- Create Stripe products and prices for each plan

To set up production:

1. Run the production seeds:
   ```bash
   mix run priv/repo/prod_seeds.exs
   ```

Note: The production seeds will only run if no super admin exists in the database. After first login, it's strongly recommended to update the super admin email and password through the account settings.

## Deployment

When deploying to production for the first time:

1. Set up your environment variables:
   ```bash
   # Stripe
   export STRIPE_SECRET_KEY="sk_live_..."
   export STRIPE_PUBLISHABLE_KEY="pk_live_..."
   
   # Email (Resend)
   export RESEND_API_KEY="re_..."
   
   # S3
   export S3_BUCKET="your-bucket"
   export S3_ACCESS_KEY_ID="your-access-key"
   export S3_SECRET_ACCESS_KEY="your-secret-key"
   export S3_REGION="your-region"
   ```

2. Deploy to Fly.io:
   ```bash
   # Initialize Fly.io deployment
   fly launch

   # Set your secrets
   fly secrets set STRIPE_SECRET_KEY="sk_live_..."
   fly secrets set STRIPE_PUBLISHABLE_KEY="pk_live_..."
   fly secrets set RESEND_API_KEY="re_..."
   fly secrets set S3_BUCKET="your-bucket"
   fly secrets set S3_ACCESS_KEY_ID="your-access-key"
   fly secrets set S3_SECRET_ACCESS_KEY="your-secret-key"
   fly secrets set S3_REGION="your-region"
   ```

This will:
- Run all pending migrations
- Create the super admin account
- Set up all subscription plans

Note: The setup task will only run the seeds if no super admin exists in the database.

Launch
- [] Deploy to Fly
- [] Purchase domain
- [] Twitter thread

Next steps
- [] Style outgoing emails
- To implemenent
  - [] WYSIWYG Editor (Quill or TipTap)
  - [] Proration charge and custom checkout
- OTP for super admin

Research
  - [] PWA
  - [] Application version (LiveNative)
  - [] Background services