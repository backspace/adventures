defmodule RegistrationsWeb.Router do
  use RegistrationsWeb, :router
  use Pow.Phoenix.Router
  use PowAssent.Phoenix.Router

  use Pow.Extension.Phoenix.Router,
    otp_app: :registrations,
    extensions: [PowResetPassword, PowInvitation]

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(RegistrationsWeb.Plugs.Settings)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
  end

  pipeline :skip_csrf_protection do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :put_secure_browser_headers
  end

  scope "/" do
    pipe_through :skip_csrf_protection

    pow_assent_authorization_post_callback_routes()
  end

  scope "/" do
    pipe_through :browser

    pow_routes()
    pow_assent_routes()
    pow_extension_routes()
  end

  scope "/", RegistrationsWeb do
    # Use the default browser stack
    pipe_through(:browser)

    post("/teams/build", TeamController, :build)
    resources("/teams", TeamController)

    resources("/users", UserController, only: [:index])
    get("/details", UserController, :edit)
    put("/details", UserController, :update)

    resources("/messages", MessageController)
    post("/messages/send-backlog", MessageController, :deliver_backlog)
    post("/messages/:id/send", MessageController, :deliver)
    get("/messages/:id/preview", MessageController, :preview)

    resources "/settings", SettingsController

    post("/questions", PageController, :questions)
    get("/", PageController, :index)
  end

  scope "/api", RegistrationsWeb do
    pipe_through(:api)

    get("/teams", TeamController, :index_json)
    patch("/users/voicepass", UserController, :voicepass)
  end
end
