# Phxplate

## Features

### User Roles and Permissions

#### Basic Users
- Create and manage their personal profile
- Bookmark companies
- Join companies as an employee (via invitation)
- Start a subscription and upgrade to admin status
- Access basic platform features

#### Admin Users
- All basic user capabilities
- Create and manage companies (limited by subscription plan)
- Manage company information and details
- Invite and remove employees from their companies
- Access premium features based on their subscription plan

#### Super Admin
- Unlimited company creation and management
- Delete any user or company via dedicated admin panel
- Modify subscription status of any user
- Change subscription plans for any user
- Complete platform administration capabilities
- Access to all features without restrictions

### Subscription Plans

The application includes three default subscription plans:

#### Small Plan
- **Price:** $15/month or $150/year
- **Features:**
  - 5 projects
  - 5GB storage
  - Email support

#### Medium Plan
- **Price:** $30/month or $300/year
- **Features:**
  - 10 projects
  - 10GB storage
  - Priority email support

#### Large Plan
- **Price:** $50/month or $500/year
- **Features:**
  - Unlimited projects
  - 20GB storage
  - 24/7 phone & email support

You can customize these plans by modifying the `plan_data` array in `lib/phxplate/application.ex`.

### Company Management System

A comprehensive company management system with role-based access:

- **Company Creation:** Admin users can create and manage companies
- **Employee Management:** Invite and manage employees with role-based permissions
- **Public Company Directory:** Browse and bookmark companies in the public directory
- **Company Profiles:** Detailed company information, logos, and descriptions
- **Employee Invitations:** Email-based invitation system for company onboarding

### Live Chat Support

The platform includes a comprehensive live chat support system:

- **User Access:** Both anonymous and signed-in users can initiate chat sessions
- **Admin Management:** Super admins can view and respond to all chat sessions via the admin panel
- **Real-time Features:** 
  - Live messaging with typing indicators
  - Session status tracking (active/closed)
  - Support status indicator (online/offline)
- **Device Information:** Automatically collects device details for troubleshooting:
  - Operating system, browser, and device type
  - Screen resolution, timezone, and language
  - IP address and user agent for technical support
- **Session Management:** Admins can close sessions and send email transcripts to users

### Feedback and Feature Requests

The platform provides a streamlined way for users to submit feedback and feature requests:

- **User Submission:** Signed-in users can submit feature requests and feedback via a dedicated form
- **Admin Tracking:** Super admins can view, manage, and respond to all submissions
- **User Linking:** Each submission is linked to the user's account for follow-up communication
- **Priority System:** 1-10 priority rating system for request categorization
- **Real-time Updates:** Live updates across admin interfaces using PubSub

### Content Management

Built-in content management capabilities:

- **Blog System:** Create and manage platform blog posts with rich content
- **Public Pages:** Dedicated pages for About, Pricing, and Contact information
- **Contact Forms:** Integrated contact form with email notifications
- **User Profiles:** Comprehensive user profile management with avatar uploads

### Administrative Features

Powerful administrative capabilities for platform management:

- **User Management:** View, edit, and manage all platform users
- **Role Management:** Assign and modify user roles (Basic, Admin, Super Admin)
- **Subscription Management:** Handle user subscriptions and plan changes
- **Platform Statistics:** Dashboard with key metrics and analytics
- **User Impersonation:** Super admin ability to impersonate users for support

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

7. Want to get up and running with Tidewave? Follow the docs [here](https://hexdocs.pm/tidewave/installation.html).

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

### Customizing Plans and Super Admin

Before deployment, you should customize the subscription plans and super admin credentials in `lib/phxplate/application.ex`:

1. Find the `create_plans_and_admin` function and modify:
   ```elixir
   # Customize plan details as needed
   plan_data = [
     %{name: "Small Plan", description: "For small teams", tier: "small", monthly_amount: 1500,
       features: %{"projects" => 5, "storage" => "5GB", "support" => "Email"}},
     %{name: "Medium Plan", description: "For medium teams", tier: "medium", monthly_amount: 3000,
       features: %{"projects" => 10, "storage" => "10GB", "support" => "Priority Email"}},
     %{name: "Large Plan", description: "For enterprise teams", tier: "large", monthly_amount: 5000,
       features: %{"projects" => "Unlimited", "storage" => "20GB", "support" => "24/7 Phone & Email"}}
   ]

   # Change super admin credentials (IMPORTANT!)
   super_admin_email = "admin@example.com"
   super_admin_password = "changeme1234"
   ```

   **IMPORTANT:** It's crucial to change the default super admin email and password before deployment.

## Deployment

When deploying to production for the first time:

1. Set up your environment variables:

   ### Environment Files
   The application uses two environment files:
   
   - `export.dev.sh`: Template file with example values for development
   - `exports.sh`: Your actual production environment
   
   ```bash
   # Copy the development template to create your production environment
   cp export.dev.sh exports.sh
   
   # Edit exports.sh with your production values:
   # - STRIPE_SECRET_KEY (use live keys)
   # - STRIPE_PUBLISHABLE_KEY (use live keys)
   # - RESEND_API_KEY
   # - BUCKET_NAME
   # - AWS_ACCESS_KEY_ID
   # - AWS_SECRET_ACCESS_KEY
   # - AWS_REGION
   ```

2. Deploy using the deployment script:
   ```bash
   # For production deployment (uses exports.sh)
   ./deploy.sh prod
   ```

   The script will:
   - Load environment variables from exports.sh
   - Launch the application on Fly.io
   - Set all required secrets
   - Deploy the application

   The first deployment will:
   - Run all pending migrations
   - Create the super admin account with the credentials specified in application.ex
   - Set up all subscription plans in Stripe and the database
   - Configure the application for subscriptions

3. Subsequent Deployments:
   ```bash
   # This will only run migrations, not the initial setup
   fly deploy
   ```

   Subsequent deployments will:
   - Only run pending migrations
   - Not create new super admin or plans
   - Preserve all existing data