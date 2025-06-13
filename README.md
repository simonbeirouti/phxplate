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

The platform includes a comprehensive live chat support system with advanced features for troubleshooting and support management:

#### **User Features:**
- **Multi-Access Support:** Both anonymous and signed-in users can initiate chat sessions
- **Real-time Messaging:** Live messaging with typing indicators and instant delivery
- **Offline Support:** When support is offline, users can still send messages and support team gets email notifications
- **Session Continuity:** Chat sessions remain active even when support agents are offline

#### **Admin Management:**
- **Unified Dashboard:** Super admins can view and respond to all chat sessions via the admin panel
- **Session Management:** Admins can close sessions and send email transcripts to users
- **Real-time Updates:** Live session monitoring with status tracking (active/closed)
- **Support Status Control:** Toggle between online/offline status with real-time updates

#### **Advanced Features:**
- **Device Information Collection:** Automatically collects troubleshooting data including:
  - Operating system, browser, and device type
  - Screen resolution, timezone, and language preferences
  - IP address and user agent for technical support
  - All collected non-intrusively for better support assistance

- **Session History & Timeline:** Comprehensive activity tracking showing:
  - Chat session started/ended events
  - Offline message attempts with email notifications sent
  - Session duration and message counts
  - Complete audit trail for support quality assurance

- **Offline Support Workflow:**
  - Users can message anytime, even when support is offline
  - Support team receives immediate email notifications with customer details
  - Chat sessions remain active for seamless support when agents return
  - Automatic activity logging for follow-up and response tracking

#### **Technical Integration:**
- **Real-time Channels:** WebSocket-based communication for instant messaging
- **Email Notifications:** Automated email alerts for offline support requests
- **Activity Tracking:** Complete audit trail using the platform's activity system
- **Device Detection:** Smart device information collection for enhanced troubleshooting

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

### AI Integration

The platform includes a comprehensive AI integration powered by Anthropic's Claude models, providing intelligent assistance and conversation capabilities:

#### **AI Chat System**
- **Multiple Claude Models:** Access to the latest Claude models including:
  - Claude 3 Haiku, Sonnet, and Opus
  - Claude 3.5 Haiku and Sonnet
  - Claude 3.7 Sonnet
  - Claude 4 Sonnet and Opus
- **Real-time Streaming:** Live streaming responses for immediate feedback
- **Conversation Management:** Persistent conversations with automatic title generation
- **Model Selection:** Choose different Claude models per conversation for optimal performance

#### **Conversation Features**
- **Persistent Chat History:** All conversations are saved and can be resumed anytime
- **Auto-Generated Titles:** Conversations are automatically titled based on content
- **Conversation Management:** Create, edit and delete conversations
- **Message Threading:** Complete conversation context maintained across sessions
- **Markdown Support:** Rich text formatting in AI responses with code highlighting

#### **Advanced AI Capabilities**
- **Custom System Prompts:** Configurable AI behavior and personality
- **Context Awareness:** AI maintains conversation context across multiple exchanges
- **Code Assistance:** Specialized support for Elixir, Phoenix, and web development
- **Streaming Responses:** Real-time response generation for better user experience
- **Error Handling:** Robust error handling with fallback mechanisms

#### **Integration Architecture**
- **Anthropix Library:** Built on the reliable Anthropix Elixir library
- **Database Persistence:** All conversations and messages stored in PostgreSQL
- **Real-time Updates:** LiveView integration for seamless user experience
- **Role-based Access:** AI features available to super admins with potential for expansion
- **Scalable Design:** Architecture supports multiple AI providers and models

#### **Technical Features**
- **Async Processing:** Non-blocking AI requests for optimal performance
- **Stream Processing:** Efficient handling of streaming AI responses
- **Message Validation:** Input validation and sanitization
- **Rate Limiting Ready:** Architecture prepared for rate limiting implementation
- **Monitoring Support:** Built-in logging and error tracking for AI interactions

### Administrative Features

Powerful administrative capabilities for platform management:

- **User Management:** View, edit, and manage all platform users
- **Role Management:** Assign and modify user roles (Basic, Admin, Super Admin)
- **Subscription Management:** Handle user subscriptions and plan changes
- **Platform Statistics:** Dashboard with key metrics and analytics
- **User Impersonation:** Super admin ability to impersonate users for support
- **AI Chat Testing:** Super admin access to AI chat interface for testing and demonstration

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
   # - ANTHROPIC_API_KEY (for AI features)
   
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

## AI Setup and Configuration

The platform includes powerful AI capabilities powered by Anthropic's Claude models. Here's how to set up and configure the AI features:

### Getting Your Anthropic API Key

1. Visit [Anthropic's Console](https://console.anthropic.com/)
2. Create an account or sign in
3. Navigate to the API Keys section
4. Generate a new API key
5. Copy the key (it starts with `sk-ant-`)

### Environment Configuration

Add your Anthropic API key to your environment variables:

```bash
# In your exports.sh file
export ANTHROPIC_API_KEY="sk-ant-your-actual-key-here"

# Load the environment
source exports.sh
```

### Available AI Features

Once configured, you'll have access to:

- **AI Chat Interface:** Available at `/dashboard/super_admin/ai-chat`
- **Multiple Claude Models:** Choose from Haiku, Sonnet, and Opus variants
- **Persistent Conversations:** All chats are saved and can be resumed
- **Streaming Responses:** Real-time AI responses for better user experience
- **Auto-Generated Titles:** Conversations are automatically titled based on content

### AI Models Available

The platform supports the following Claude models:

| Model | API ID | Best For |
|-------|--------|----------|
| Haiku 3 | `claude-3-haiku-20240307` | Fast, lightweight tasks |
| Sonnet 3 | `claude-3-sonnet-20240229` | Balanced performance |
| Opus 3 | `claude-3-opus-20240229` | Complex reasoning |
| Haiku 3.5 | `claude-3-5-haiku-20241022` | Improved fast responses |
| Sonnet 3.5 | `claude-3-5-sonnet-20241022` | Enhanced capabilities |
| Sonnet 3.7 | `claude-3-7-sonnet-20250219` | Latest improvements |
| Sonnet 4 | `claude-sonnet-4-20250514` | Next-generation model |
| Opus 4 | `claude-opus-4-20250514` | Most advanced reasoning |

### Customizing AI Behavior

You can customize the AI's behavior by modifying the system prompt in `lib/phxplate_web/live/dashboard/super_admin/ai_chat_live.ex`:

```elixir
@system_prompt """
You are a helpful AI assistant integrated into a Phoenix application.
You provide clear, concise, and accurate responses while maintaining a professional tone.
When discussing code or technical topics, you provide practical examples and explanations.
You are knowledgeable about Elixir, Phoenix, LiveView, and web development in general.
Keep your responses focused and relevant to the user's questions.
"""
```

### Extending AI Features

The AI module (`lib/phxplate/ai.ex`) provides several functions for integrating AI capabilities throughout your application:

- `Phxplate.AI.chat/3` - Simple text-based AI interactions
- `Phxplate.AI.stream_chat/3` - Streaming AI responses
- `Phxplate.AI.chat_conversation/3` - Multi-turn conversations
- `Phxplate.AI.create_conversation/3` - Persistent conversation management

### Troubleshooting AI Setup

If you encounter issues with AI features:

1. **Check API Key:** Ensure your `ANTHROPIC_API_KEY` is correctly set
2. **Verify Network:** Ensure your server can reach Anthropic's API
3. **Check Logs:** Look for AI-related errors in your Phoenix logs
4. **Test Connection:** Use the AI chat interface to test connectivity

The AI integration is designed to fail gracefully - if the API is unavailable, the application will continue to function normally without AI features.

### What You Can Achieve with AI Integration

The AI integration opens up numerous possibilities for enhancing your application:

#### **Customer Support Enhancement**
- **Intelligent Chatbots:** Create AI-powered customer support bots
- **FAQ Automation:** Automatically answer common questions
- **Ticket Triage:** AI can help categorize and prioritize support tickets
- **Multi-language Support:** Leverage Claude's multilingual capabilities

#### **Content Generation**
- **Blog Post Assistance:** Generate ideas, outlines, or full blog posts
- **Marketing Copy:** Create compelling marketing materials and descriptions
- **Documentation:** Auto-generate API documentation or user guides
- **Email Templates:** Create personalized email templates and responses

#### **Code Assistance**
- **Code Review:** AI can help review code and suggest improvements
- **Bug Debugging:** Assist in identifying and fixing code issues
- **Feature Development:** Get suggestions for implementing new features
- **Architecture Advice:** Receive guidance on system design and architecture

#### **Business Intelligence**
- **Data Analysis:** Analyze business metrics and provide insights
- **Report Generation:** Create automated reports with AI-generated summaries
- **Trend Analysis:** Identify patterns and trends in your data
- **Decision Support:** Get AI-powered recommendations for business decisions

#### **User Experience Enhancement**
- **Personalized Recommendations:** Provide tailored suggestions to users
- **Smart Search:** Implement intelligent search with natural language queries
- **Content Curation:** Automatically curate and organize content
- **User Onboarding:** Create intelligent onboarding flows

#### **Development and Operations**
- **Log Analysis:** AI can help analyze application logs for issues
- **Performance Monitoring:** Get insights into application performance
- **Security Analysis:** Identify potential security vulnerabilities
- **Deployment Assistance:** Get help with deployment and configuration

#### **Integration Examples**

Here are some practical ways to extend the AI functionality:

```elixir
# Example: AI-powered content moderation
def moderate_content(content) do
  prompt = "Analyze this content for inappropriate material: #{content}"
  case Phxplate.AI.chat(prompt, "You are a content moderator.") do
    {:ok, response} -> parse_moderation_response(response)
    {:error, _} -> {:error, :moderation_failed}
  end
end

# Example: Smart email responses
def generate_email_response(customer_message, context) do
  prompt = """
  Customer message: #{customer_message}
  Context: #{context}
  Generate a helpful, professional response.
  """
  Phxplate.AI.chat(prompt, "You are a customer service representative.")
end

# Example: Code documentation generation
def generate_documentation(code) do
  prompt = "Generate documentation for this Elixir code: #{code}"
  Phxplate.AI.chat(prompt, "You are a technical documentation expert.")
end
```

The AI integration provides a solid foundation that you can build upon to create intelligent, responsive applications that provide exceptional user experiences.

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
   # - ANTHROPIC_API_KEY (for AI features)
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