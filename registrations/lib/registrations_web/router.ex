defmodule RegistrationsWeb.Router do
  use RegistrationsWeb, :router
  use Pow.Phoenix.Router
  use PowAssent.Phoenix.Router

  use Pow.Extension.Phoenix.Router,
    otp_app: :registrations,
    extensions: [PowResetPassword, PowInvitation, PowPersistentSession]

  alias Pow.Plug.RequireAuthenticated

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)

    plug(RegistrationsWeb.Plugs.Settings)

    plug(Pow.Plug.Session, otp_app: :registrations)
    plug(PowPersistentSession.Plug.Cookie)

    plug(PowAssent.Plug.Reauthorization,
      handler: PowAssent.Phoenix.ReauthorizationPlugHandler
    )
  end

  pipeline :jsonapi do
    plug(JSONAPI.EnsureSpec)
    plug(JSONAPI.Deserializer)
    plug(JSONAPI.UnderscoreParameters)
  end

  pipeline :jsonapi_with_session do
    plug(:fetch_session)
    plug(:jsonapi)
  end

  pipeline :pow_api do
    plug(:accepts, ["json"])
    plug(RegistrationsWeb.PowAuthPlug, otp_app: :registrations)
  end

  pipeline :pow_api_protected do
    plug(RequireAuthenticated, error_handler: RegistrationsWeb.PowAuthErrorHandler)
  end

  pipeline :pow_json_api_protected do
    plug(JSONAPI.EnsureSpec)
    plug(JSONAPI.Deserializer)
    plug(JSONAPI.UnderscoreParameters)
    plug(RegistrationsWeb.PowAuthPlug, otp_app: :registrations)
    plug(RequireAuthenticated, error_handler: RegistrationsWeb.PowAuthErrorHandler)
  end

  pipeline :pow_json_api_protected_admin do
    plug(:pow_json_api_protected)
    plug(RegistrationsWeb.Plugs.AdminAPI)
  end

  pipeline :poles_author do
    plug(:accepts, ["json"])
    plug(RegistrationsWeb.PowAuthPlug, otp_app: :registrations)
    plug(Pow.Plug.RequireAuthenticated, error_handler: RegistrationsWeb.PowAuthErrorHandler)
    plug(RegistrationsWeb.Plugs.RequireRole, role: "author")
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

    post("/invitations", RegistrationsWeb.InvitationController, :create)
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

    get("/delete", UserController, :delete_show)
    post("/delete", UserController, :delete)
    put("/delete", UserController, :delete)

    post("/questions", PageController, :questions)
    post("/waitlist", PageController, :waitlist)
    get("/", PageController, :index)
  end

  scope "/api", RegistrationsWeb do
    pipe_through(:browser)

    get("/teams", TeamController, :index_json)
    patch("/users/voicepass", UserController, :voicepass)
  end

  scope "/powapi", RegistrationsWeb do
    pipe_through(:pow_api)

    resources("/registration", ApiRegistrationController, singleton: true, only: [:create])
    resources("/session", ApiSessionController, singleton: true, only: [:create, :delete])
    post("/session/renew", ApiSessionController, :renew)

    get("/auth/:provider/new", ApiAuthorizationController, :new)
    post("/auth/:provider/callback", ApiAuthorizationController, :callback)
  end

  scope "/waydowntown", RegistrationsWeb do
    pipe_through(:jsonapi)

    resources("/regions", RegionController, only: [:index])
    resources("/specifications", SpecificationController, only: [:index])
  end

  scope "/waydowntown", RegistrationsWeb do
    pipe_through([:pow_json_api_protected])

    resources("/regions", RegionController, only: [:create, :update])
  end

  scope "/waydowntown", RegistrationsWeb do
    pipe_through([:pow_json_api_protected_admin])

    resources("/regions", RegionController, only: [:delete])
    resources("/user-roles", UserRoleController, only: [:index, :create, :delete])
    get("/users", UserRoleController, :users)
  end

  scope "/waydowntown", RegistrationsWeb do
    pipe_through([:pow_json_api_protected])

    get("/team-negotiation", TeamNegotiationController, :show)

    resources "/participations", ParticipationController, only: [:create, :update]
    resources "/reveals", RevealController, only: [:create]

    resources("/runs", RunController, except: [:new, :edit, :delete, :update]) do
      post "/start", RunController, :start, as: :start
    end

    resources("/answers", AnswerController, only: [:create, :update, :delete])

    resources("/specifications", SpecificationController, only: [:create, :update])
    get("/specifications/mine", SpecificationController, :mine, as: :my_specifications)

    resources("/submissions", SubmissionController, only: [:create, :show])

    get("/specification-validations/mine", SpecificationValidationController, :mine, as: :my_validations)
    get("/specification-validations/supervise", SpecificationValidationController, :supervise, as: :supervise_validations)
    resources("/specification-validations", SpecificationValidationController, only: [:index, :show, :create, :update])

    resources("/validation-comments", ValidationCommentController, only: [:create, :update, :delete])

    get("/validators", UserRoleController, :validators)
  end

  scope "/poles", RegistrationsWeb.Poles, as: :poles do
    pipe_through([:pow_api, :pow_api_protected])

    get("/me", MeController, :show)
    get("/poles", PoleController, :index)
    get("/poles/:barcode", PoleController, :show)
    post("/puzzlets/:puzzlet_id/attempts", AttemptController, :create)
  end

  scope "/poles/drafts", RegistrationsWeb.Poles, as: :poles_drafts do
    pipe_through([:poles_author])

    get("/mine", DraftController, :index)
    post("/poles", DraftController, :create_pole)
    patch("/poles/:id", DraftController, :update_pole)
    delete("/poles/:id", DraftController, :delete_pole)
    post("/puzzlets", DraftController, :create_puzzlet)
    patch("/puzzlets/:id", DraftController, :update_puzzlet)
    delete("/puzzlets/:id", DraftController, :delete_puzzlet)
  end

  scope "/fixme", RegistrationsWeb do
    pipe_through([:pow_json_api_protected])

    get("/session", SessionController, :show)
    post("/me", ApiUserController, :update)
  end

  if Mix.env() == :test do
    scope "/test", RegistrationsWeb do
      pipe_through(:pow_api)

      post("/reset", TestController, :reset)
    end
  end

  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through [:browser]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
