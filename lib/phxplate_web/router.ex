defmodule PhxplateWeb.Router do
  @moduledoc """
  Defines all the routes and pipelines for the Phxplate application.

  This module organizes routes into various scopes and applies appropriate
  pipelines to enforce authentication, authorization, and other requirements
  for different parts of the application.

  Key sections include:
  - Public routes for unauthenticated users
  - Authentication routes for login/registration
  - Dashboard routes with role-based authorization
  - Webhook and callback endpoints
  """
  use PhxplateWeb, :router

  import PhxplateWeb.UserAuth
  import Phoenix.LiveView.Router

  @doc """
  Pipeline for browser requests.

  Sets up common requirements for HTML pages including session management,
  LiveView flash messages, CSRF protection, and user authentication.
  """
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhxplateWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :assign_current_path
  end

  defp assign_current_path(conn, _opts) do
    assign(conn, :current_path, conn.request_path)
  end

  @doc """
  Pipeline for API requests.

  Configures the connection to accept JSON requests.
  """
  pipeline :api do
    plug :accepts, ["json"]
  end

  @doc """
  Pipeline for admin-level access.

  Ensures the current user has admin privileges.
  """
  pipeline :admin do
    plug PhxplateWeb.Authorization, :admin
  end

  @doc """
  Pipeline for super admin-level access.

  Ensures the current user has super admin privileges.
  """
  pipeline :super_admin do
    plug PhxplateWeb.Authorization, :super_admin
  end

  @doc """
  Pipeline for basic user access.

  Ensures the current user has at least basic user privileges.
  """
  pipeline :basic do
    plug PhxplateWeb.Authorization, :basic
  end

  # Public routes accessible without authentication
  scope "/", PhxplateWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/about", PageController, :about

    # Chat is now handled by the ChatButton component in the root layout

    live_session :public,
      on_mount: [{PhxplateWeb.UserAuth, :mount_current_user}],
      layout: {PhxplateWeb.Layouts, :public} do
      live "/contact", ContactLive, :index
      live "/pricing", PricingLive, :index
      live "/companies", Public.CompaniesLive, :index
      live "/companies/:id", Public.CompanyShowLive, :show
      live "/blog", Public.BlogLive, :index
      live "/blog/:slug", Public.BlogShowLive, :show
    end
  end

  # Stripe callback routes
  scope "/callbacks", PhxplateWeb do
    pipe_through :browser

    get "/stripe/success", StripeController, :success
    get "/stripe/cancel", StripeController, :cancel
  end

  # Webhook endpoint needs :api pipeline instead of :browser
  # scope "/callbacks", PhxplateWeb do
  #   pipe_through :api

  #   post "/stripe/webhook", StripeController, :webhook
  # end

  # API routes for chat functionality
  scope "/api", PhxplateWeb do
    pipe_through :api

    post "/chat", ChatController, :create
    get "/chat/anonymous/:email", ChatController, :get_anonymous_sessions
    get "/chat/:id", ChatController, :get_session
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:phxplate, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PhxplateWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  # Routes for unauthenticated users
  scope "/", PhxplateWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      layout: {PhxplateWeb.Layouts, :auth},
      on_mount: [{PhxplateWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/register", UserRegistrationLive, :new
      live "/login", UserLoginLive, :new
      live "/reset-password", UserForgotPasswordLive, :new
      live "/reset-password/:token", UserResetPasswordLive, :edit
    end

    post "/login", UserSessionController, :create
  end

  # Logout route and email confirmation
  scope "/", PhxplateWeb do
    pipe_through [:browser]

    delete "/logout", UserSessionController, :delete

    live_session :current_user,
      layout: {PhxplateWeb.Layouts, :auth},
      on_mount: [{PhxplateWeb.UserAuth, :mount_current_user}] do
      live "/confirm/:token", UserConfirmationLive, :edit
      live "/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  # Onboarding routes for authenticated users
  scope "/onboarding", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :onboarding,
      layout: {PhxplateWeb.Layouts, :auth},
      on_mount: [
        {PhxplateWeb.UserAuth, :ensure_authenticated}
      ] do
      live "/", Onboarding.ProfileLive, :index
    end
  end

  # Dashboard routes with role-based access control
  scope "/dashboard", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user]

    # Impersonation routes
    get "/impersonate/:id", UserImpersonationController, :impersonate
    get "/stop_impersonating", UserImpersonationController, :stop_impersonating

    live_session :dashboard,
      layout: {PhxplateWeb.Layouts, :app},
      on_mount: [
        {PhxplateWeb.UserAuth, :ensure_authenticated},
        {PhxplateWeb.UserAuth, :ensure_proper_role},
        {PhxplateWeb.Live.Hooks.LayoutHooks, :default}
      ] do
      live "/", DashboardLive, :index
      live "/account", Dashboard.User.UserAccountLive, :index
      live "/account/confirm_email/:token", Dashboard.User.UserAccountLive, :confirm_email
      live "/invites", Dashboard.User.InvitesLive, :index
      live "/invites/:token", Dashboard.User.InvitesLive, :accept

      pipe_through [:basic]
      live "/basic", Dashboard.Basic.BasicLive, :index
      live "/basic/bookmarks", Dashboard.Basic.BookmarksLive, :index
      live "/companies/:id", Dashboard.Company.CompanyViewLive, :index

      pipe_through [:admin]
      live "/admin", Dashboard.Admin.AdminLive, :index
      live "/admin/companies", Dashboard.Admin.CompanyLive, :index
      live "/admin/companies/:id", Dashboard.Admin.CompanyShowLive, :index

      pipe_through [:super_admin]
      live "/super_admin", Dashboard.SuperAdmin.SuperAdminLive, :index
      live "/super_admin/blogs", Dashboard.SuperAdmin.BlogsLive, :index
      live "/super_admin/feature-feedbacks", Dashboard.SuperAdmin.FeedbackRequestsLive, :index
      live "/super_admin/users", Dashboard.SuperAdmin.UsersLive, :index
      live "/super_admin/companies", Dashboard.SuperAdmin.CompaniesLive, :index
      live "/super_admin/chat", Admin.ChatDashboardLive, :index
      live "/super_admin/ai-chat", Dashboard.SuperAdmin.AiChatLive, :index
      live "/super_admin/ai-chat/:conversation_id", Dashboard.SuperAdmin.AiChatLive, :show
      live "/super_admin/ai-prompts", Dashboard.SuperAdmin.AiPromptsLive, :index
      live "/super_admin/ai-evals", Dashboard.SuperAdmin.AiEvalsLive, :index
      live "/super_admin/ai-results", Dashboard.SuperAdmin.AiResultsLive, :index
    end
  end
end
