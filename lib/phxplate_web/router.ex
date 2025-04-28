# lib/phxplate_web/router.ex
# ##############################################################################
# EDIT THIS FILE
# ##############################################################################
defmodule PhxplateWeb.Router do
  alias PhxplateWeb.Components.DashboardLayout # Keep alias if used elsewhere, otherwise optional
  use PhxplateWeb, :router

  import PhxplateWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    # This plug now correctly applies the root layout (which includes app.html.heex)
    # to ALL browser requests unless overridden by a controller/view specifically.
    plug :put_root_layout, html: {PhxplateWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :assign_current_path
  end

  defp assign_current_path(conn, _opts) do
    assign(conn, :current_path, conn.request_path)
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admin do
    plug PhxplateWeb.Authorization, :admin
  end

  pipeline :super_admin do
    plug PhxplateWeb.Authorization, :super_admin
  end

  pipeline :basic do
    plug PhxplateWeb.Authorization, :basic
  end

  # REMOVE the :dashboard pipeline entirely
  # pipeline :dashboard do
  #   # plug :put_root_layout, {PhxplateWeb.Layouts, :dashboard} # This was the problematic line
  # end

  scope "/", PhxplateWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/companies", CompanyController, :public_index
    get "/companies/:id", CompanyController, :public_show
    get "/profiles", ProfileController, :public_index
    get "/profiles/:id", ProfileController, :public_show
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhxplateWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:phxplate, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PhxplateWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", PhxplateWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{PhxplateWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{PhxplateWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", PhxplateWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{PhxplateWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  # Dashboard routes
  # Remove :dashboard from pipe_through
  scope "/dashboard", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user] # REMOVED :dashboard

    # If DashboardLive renders the <.dashboard_layout> component itself, keep it.
    # Otherwise, change to `get "/", DashboardController, :index`
    live "/", DashboardLive, :index
    get "/companies", CompanyController, :dashboard_index # Assuming CompanyController handles its own layout/view
    get "/companies/:id", CompanyController, :dashboard_show # Assuming CompanyController handles its own layout/view
  end

  # Remove :dashboard from pipe_through
  scope "/dashboard/basic", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user, :basic] # REMOVED :dashboard

    get "/", DashboardController, :basic
    get "/reports", DashboardController, :basic_reports
    get "/settings", DashboardController, :basic_settings
    get "/companies", DashboardController, :basic_companies # Keep if DashboardController renders these
    get "/companies/:id", DashboardController, :basic_company_show # Keep if DashboardController renders these
  end

  # Remove :dashboard from pipe_through
  scope "/dashboard/admin", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user, :admin] # REMOVED :dashboard

    get "/", DashboardController, :admin
    get "/companies", DashboardController, :admin_companies
    get "/companies/:id", DashboardController, :admin_company_show
    get "/users", DashboardController, :admin_users
    get "/settings", DashboardController, :admin_settings
  end

  # Remove :dashboard from pipe_through
  scope "/dashboard/super_admin", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user, :super_admin] # REMOVED :dashboard

    get "/", DashboardController, :super_admin
    get "/config", DashboardController, :super_admin_config
    get "/audit", DashboardController, :super_admin_audit
    get "/companies", DashboardController, :super_admin_companies
    get "/companies/:id", DashboardController, :super_admin_company_show
  end

  # Company routes - accessible to all authenticated users
  # These likely don't need the dashboard layout component directly, adjust if needed.
  scope "/companies", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :companies,
      on_mount: [{PhxplateWeb.UserAuth, :ensure_authenticated}] do
      live "/", CompanyLive.Index, :index
      live "/new", CompanyLive.Index, :new
      live "/:id", CompanyLive.Show, :show
      live "/:id/edit", CompanyLive.Index, :edit
    end
  end

  # Admin company management routes
  # These likely don't need the dashboard layout component directly, adjust if needed.
  scope "/admin/companies", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user, :admin]

    live_session :admin_companies,
      on_mount: [
        {PhxplateWeb.UserAuth, :ensure_authenticated},
        {PhxplateWeb.Authorization, :admin} # Ensure this plug works correctly standalone
      ] do
      live "/", CompanyLive.Index, :index
      live "/new", CompanyLive.Index, :new
      live "/:id", CompanyLive.Show, :show
      live "/:id/edit", CompanyLive.Index, :edit
    end
  end

  # Super admin company management routes
  # These likely don't need the dashboard layout component directly, adjust if needed.
  scope "/super_admin/companies", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user, :super_admin]

    live_session :super_admin_companies,
      on_mount: [
        {PhxplateWeb.UserAuth, :ensure_authenticated},
        {PhxplateWeb.Authorization, :super_admin} # Ensure this plug works correctly standalone
      ] do
      live "/", CompanyLive.Index, :index
      live "/new", CompanyLive.Index, :new
      live "/:id", CompanyLive.Show, :show
      live "/:id/edit", CompanyLive.Index, :edit
      live "/:id/delete", CompanyLive.Index, :delete # Assuming delete is handled within the LiveView
    end
  end
end
