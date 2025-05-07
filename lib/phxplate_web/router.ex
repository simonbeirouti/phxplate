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
    get "/about", PageController, :about
    get "/contact", PageController, :contact

    live_session :public,
      on_mount: [{PhxplateWeb.UserAuth, :mount_current_user}],
      layout: {PhxplateWeb.Layouts, :public} do
      live "/pricing", PricingLive, :index
      live "/companies", Public.CompaniesLive, :index
      live "/companies/:id", Public.CompanyShowLive, :show
    end
  end

  scope "/callbacks", PhxplateWeb do
    pipe_through :browser

    get "/stripe/success", StripeController, :success
    get "/stripe/cancel", StripeController, :cancel
  end

  # Webhook endpoint needs :api pipeline instead of :browser
  scope "/callbacks", PhxplateWeb do
    pipe_through :api

    post "/stripe/webhook", StripeController, :webhook
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
      layout: {PhxplateWeb.Layouts, :auth},
      on_mount: [{PhxplateWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/register", UserRegistrationLive, :new
      live "/login", UserLoginLive, :new
      live "/reset_password", UserForgotPasswordLive, :new
      live "/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/login", UserSessionController, :create
  end

  scope "/", PhxplateWeb do
    pipe_through [:browser]

    delete "/logout", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{PhxplateWeb.UserAuth, :mount_current_user}] do
      live "/confirm/:token", UserConfirmationLive, :edit
      live "/confirm", UserConfirmationInstructionsLive, :new
    end
  end

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
      live "/profile", Dashboard.User.UserProfileLive, :index
      live "/settings", Dashboard.User.UserSettingsLive, :edit
      live "/billing", Dashboard.User.BillingLive, :index
      live "/settings/confirm_email/:token", Dashboard.User.UserSettingsLive, :confirm_email

      pipe_through [:basic]
      live "/basic", Dashboard.Basic.BasicLive, :index
      live "/basic/basicpage", Dashboard.Basic.BasicPageLive, :index
      live "/basic/basicpage2", Dashboard.Basic.SecondPageLive, :index

      pipe_through [:admin]
      live "/admin", Dashboard.Admin.AdminLive, :index
      live "/admin/companies", Dashboard.Admin.CompanyLive, :index
      live "/admin/company/:id", Dashboard.Admin.CompanyShowLive, :index

      pipe_through [:super_admin]
      live "/super_admin", Dashboard.SuperAdmin.SuperAdminLive, :index
      live "/super_admin/users", Dashboard.SuperAdmin.UsersLive, :index
      live "/super_admin/companies", Dashboard.SuperAdmin.CompaniesLive, :index
    end
  end
end
