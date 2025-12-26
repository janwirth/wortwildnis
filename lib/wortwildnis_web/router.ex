defmodule WortwildnisWeb.Router do
  use WortwildnisWeb, :router

  import Oban.Web.Router
  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WortwildnisWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
    plug :set_actor, :user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", WortwildnisWeb do
    pipe_through :browser

    get "/sitemap.xml", SitemapController, :index

    ash_authentication_live_session :authenticated_routes do
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {WortwildnisWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {WortwildnisWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {WortwildnisWeb.LiveUserAuth, :live_no_user}

      # get "/", PageController, :home
      live "/", TermLive.Index, :index
      live "/neu", TermLive.Index, :recent
      live "/index-refactor", TermLive.IndexRefactor, :index
      live "/terms/new", TermLive.Form, :new
      live "/terms/:id/edit", TermLive.Form, :edit
      live "/definition/:q", TermLive.Index, :show
      live "/alphabetisch", AlphabetLive.Index, :index
      live "/alphabetisch/:letter", TermLive.Index, :index
      live "/profile", TermLive.Index, :profile
    end
  end

  scope "/", WortwildnisWeb do
    pipe_through :browser

    auth_routes AuthController, Wortwildnis.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{WortwildnisWeb.LiveUserAuth, :live_no_user}],
                  gettext_backend: {WortwildnisWeb.Gettext, "auth"},
                  overrides: [
                    WortwildnisWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI,
                    AshAuthentication.Phoenix.Overrides.Default
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                gettext_backend: {WortwildnisWeb.Gettext, "auth"},
                overrides: [
                  WortwildnisWeb.AuthOverrides,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]

    # Remove this if you do not use the confirmation strategy
    confirm_route Wortwildnis.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      gettext_backend: {WortwildnisWeb.Gettext, "auth"},
      overrides: [
        WortwildnisWeb.AuthOverrides,
        Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
      ]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Wortwildnis.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      gettext_backend: {WortwildnisWeb.Gettext, "auth"},
      overrides: [
        WortwildnisWeb.AuthOverrides,
        Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
      ]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", WortwildnisWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:wortwildnis, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WortwildnisWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/" do
      pipe_through :browser

      oban_dashboard("/oban", resolver: WortwildnisWeb.ObanResolve)
    end
  end

  if Application.compile_env(:wortwildnis, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
