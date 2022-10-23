defmodule Cr2016siteWeb.Router do
  use Cr2016siteWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(Cr2016siteWeb.Plugs.CurrentUser)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(Cr2016siteWeb.Plugs.CurrentUser)
  end

  scope "/", Cr2016siteWeb do
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

  scope "/api", Cr2016siteWeb do
    pipe_through(:api)

    get("/teams", TeamController, :index_json)
  end
end
