defmodule AdventureRegistrationsWeb.Router do
  use AdventureRegistrationsWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(AdventureRegistrationsWeb.Plugs.CurrentUser)
    plug(AdventureRegistrationsWeb.Plugs.Settings)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(AdventureRegistrationsWeb.Plugs.CurrentUser)
  end

  scope "/", AdventureRegistrationsWeb do
    # Use the default browser stack
    pipe_through(:browser)

    get("/register", RegistrationController, :new)
    post("/register", RegistrationController, :create)

    get("/login", SessionController, :new)
    post("/login", SessionController, :create)
    delete("/logout", SessionController, :delete)

    post("/teams/build", TeamController, :build)
    resources("/teams", TeamController)

    resources("/users", UserController, only: [:index])
    get("/details", UserController, :edit)
    put("/details", UserController, :update)

    get("/account", RegistrationController, :edit)
    put("/account", RegistrationController, :update)

    get("/delete", RegistrationController, :maybe_delete)
    put("/delete", RegistrationController, :delete)

    get("/reset", ResetController, :new)
    post("/reset", ResetController, :create)
    get("/reset/:token", ResetController, :edit)
    put("/reset/:token", ResetController, :update)

    resources("/messages", MessageController)
    post("/messages/:id/send", MessageController, :deliver)
    get("/messages/:id/preview", MessageController, :preview)

    post("/questions", PageController, :questions)
    get("/", PageController, :index)
  end

  scope "/api", AdventureRegistrationsWeb do
    pipe_through(:api)

    get("/teams", TeamController, :index_json)
    patch("/users/voicepass", UserController, :voicepass)
  end
end
