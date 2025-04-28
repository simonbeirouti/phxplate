defmodule PhxplateWeb.Router do
  use PhxplateWeb, :router

  import PhxplateWeb.UserAuth

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

  scope "/", PhxplateWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhxplateWeb do
  #   pipe_through :api
  # end

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
  scope "/dashboard", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/", DashboardController, :index
    get "/companies", DashboardController, :companies
    get "/companies/:id", DashboardController, :company_show
  end

  scope "/dashboard/basic", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user, :basic]

    get "/", DashboardController, :basic
    get "/reports", DashboardController, :basic_reports
    get "/settings", DashboardController, :basic_settings
    get "/companies", DashboardController, :basic_companies
    get "/companies/:id", DashboardController, :basic_company_show
  end

  scope "/dashboard/admin", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user, :admin]

    get "/", DashboardController, :admin
    get "/companies", DashboardController, :admin_companies
    get "/companies/:id", DashboardController, :admin_company_show
    get "/users", DashboardController, :admin_users
    get "/settings", DashboardController, :admin_settings
  end

  scope "/dashboard/super_admin", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user, :super_admin]

    get "/", DashboardController, :super_admin
    get "/config", DashboardController, :super_admin_config
    get "/audit", DashboardController, :super_admin_audit
    get "/companies", DashboardController, :super_admin_companies
    get "/companies/:id", DashboardController, :super_admin_company_show
  end

  # Company routes - accessible to all authenticated users
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
  scope "/admin/companies", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user, :admin]

    live_session :admin_companies,
      on_mount: [
        {PhxplateWeb.UserAuth, :ensure_authenticated},
        {PhxplateWeb.Authorization, :admin}
      ] do
      live "/", CompanyLive.Index, :index
      live "/new", CompanyLive.Index, :new
      live "/:id", CompanyLive.Show, :show
      live "/:id/edit", CompanyLive.Index, :edit
    end
  end

  # Super admin company management routes
  scope "/super_admin/companies", PhxplateWeb do
    pipe_through [:browser, :require_authenticated_user, :super_admin]

    live_session :super_admin_companies,
      on_mount: [
        {PhxplateWeb.UserAuth, :ensure_authenticated},
        {PhxplateWeb.Authorization, :super_admin}
      ] do
      live "/", CompanyLive.Index, :index
      live "/new", CompanyLive.Index, :new
      live "/:id", CompanyLive.Show, :show
      live "/:id/edit", CompanyLive.Index, :edit
      live "/:id/delete", CompanyLive.Index, :delete
    end
  end
end
