defmodule RiceMillWeb.Router do
  use RiceMillWeb, :router

  import RiceMillWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RiceMillWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug RiceMillWeb.Plugs.SetCurrentPath
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_super_admin do
    plug RiceMillWeb.Plugs.RequireRole, [:super_admin]
  end

  pipeline :require_company_admin do
    plug RiceMillWeb.Plugs.RequireRole, [:company_admin]
  end

  pipeline :redirect_authenticated_user do
    plug :redirect_if_user_is_authenticated
  end

  scope "/", RiceMillWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Health check endpoint (no authentication required)
  scope "/", RiceMillWeb do
    get "/health", HealthController, :check
  end

  # Other scopes may use custom stacks.
  # scope "/api", RiceMillWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:rice_mill, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RiceMillWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", RiceMillWeb do
    pipe_through [:browser, :require_authenticated_user, RiceMillWeb.Plugs.TenantContext]

    live_session :require_authenticated_user,
      on_mount: [
        {RiceMillWeb.UserAuth, :require_authenticated},
        {RiceMillWeb.UserAuth, :set_current_path}
      ],
      layout: {RiceMillWeb.Layouts, :app} do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

      # User profile - accessible to all authenticated users
      live "/users/profile", UserProfileLive.Index, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  ## Inventory routes (tenant users only - company_admin, operator, viewer)
  scope "/", RiceMillWeb do
    pipe_through [:browser, :require_authenticated_user, RiceMillWeb.Plugs.TenantContext]

    # Dashboard export route (controller-based for file download)
    get "/dashboard/export", DashboardExportController, :export

    live_session :tenant_inventory,
      on_mount: [
        {RiceMillWeb.UserAuth, :require_authenticated},
        {RiceMillWeb.UserAuth, :require_tenant_user},
        {RiceMillWeb.UserAuth, :set_current_path}
      ],
      layout: {RiceMillWeb.Layouts, :app} do
      # Dashboard - main landing page for tenant users
      live "/dashboard", DashboardLive.Index, :index

      # Inventory management routes
      live "/products", ProductLive.Index, :index
      live "/products/new", ProductLive.Index, :new
      live "/products/:id/edit", ProductLive.Index, :edit

      live "/stock-ins", StockInLive.Index, :index
      live "/stock-ins/new", StockInLive.Index, :new

      live "/stock-outs", StockOutLive.Index, :index
      live "/stock-outs/new", StockOutLive.Index, :new

      # Reports - unified page with tabs
      live "/reports", ReportLive.Index, :index
    end
  end

  ## Tenant settings routes (company_admin and super_admin only)
  scope "/settings", RiceMillWeb do
    pipe_through [
      :browser,
      :require_authenticated_user,
      :require_company_admin,
      RiceMillWeb.Plugs.TenantContext
    ]

    live_session :tenant_settings,
      on_mount: [
        {RiceMillWeb.UserAuth, :require_authenticated},
        {RiceMillWeb.UserAuth, :set_current_path}
      ],
      layout: {RiceMillWeb.Layouts, :app} do
      live "/tenant", TenantSettingsLive.Index, :index
    end
  end

  ## User management routes (company_admin only)
  scope "/users/manage", RiceMillWeb do
    pipe_through [
      :browser,
      :require_authenticated_user,
      :require_company_admin,
      RiceMillWeb.Plugs.TenantContext
    ]

    live_session :company_admin_user_management,
      on_mount: [
        {RiceMillWeb.UserAuth, :require_authenticated},
        {RiceMillWeb.UserAuth, :set_current_path}
      ],
      layout: {RiceMillWeb.Layouts, :app} do
      # User management
      live "/", UserManagementLive.Index, :index
      live "/new", UserManagementLive.Index, :new
      live "/:id/edit", UserManagementLive.Index, :edit

      # Invitation management
      live "/invite", UserManagementLive.InvitationForm, :new

      # Bulk import
      live "/import", UserManagementLive.BulkImport, :index

      # Audit logs (company admin view - tenant scoped)
      live "/audit-logs", Admin.AuditLogLive.Index, :index
    end
  end

  ## Admin routes (super_admin only)
  scope "/admin", RiceMillWeb do
    pipe_through [
      :browser,
      :require_authenticated_user,
      :require_super_admin,
      RiceMillWeb.Plugs.TenantContext
    ]

    live_session :admin_super_admin,
      on_mount: [
        {RiceMillWeb.UserAuth, :require_authenticated},
        {RiceMillWeb.UserAuth, :set_current_path}
      ],
      layout: {RiceMillWeb.Layouts, :app} do
      # Dashboard
      live "/dashboard", Admin.DashboardLive.Index, :index

      # Tenant management
      live "/tenants", Admin.TenantLive.Index, :index
      live "/tenants/new", Admin.TenantLive.Index, :new
      live "/tenants/:id", Admin.TenantLive.Show, :show
      live "/tenants/:id/edit", Admin.TenantLive.Show, :edit

      # User management (all users across all tenants)
      live "/users", Admin.AdminUserLive.Index, :index
      live "/users/new", Admin.AdminUserLive.Index, :new
      live "/users/:id/edit", Admin.AdminUserLive.Index, :edit

      # Audit logs (all tenants)
      live "/audit-logs", Admin.AuditLogLive.Index, :index
    end
  end

  scope "/", RiceMillWeb do
    pipe_through [:browser, :redirect_authenticated_user]

    live_session :current_user,
      on_mount: [{RiceMillWeb.UserAuth, :mount_current_scope}],
      layout: {RiceMillWeb.Layouts, :root} do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
      live "/invitations/:token/accept", UserInvitationLive.Accept, :new
    end

    post "/users/log-in", UserSessionController, :create
  end

  scope "/", RiceMillWeb do
    pipe_through [:browser]

    delete "/users/log-out", UserSessionController, :delete
  end
end
