defmodule RegistrationsWeb.Router do
  use RegistrationsWeb, :router
  use Pow.Phoenix.Router
  use PowAssent.Phoenix.Router

  use Pow.Extension.Phoenix.Router,
    otp_app: :registrations,
    extensions: [PowResetPassword, PowInvitation, PowPersistentSession]

  alias Pow.Plug.RequireAuthenticated
  alias RegistrationsWeb.Plugs.RequireRole

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

  pipeline :landgrab_author do
    plug(:accepts, ["json"])
    plug(RegistrationsWeb.PowAuthPlug, otp_app: :registrations)
    plug(Pow.Plug.RequireAuthenticated, error_handler: RegistrationsWeb.PowAuthErrorHandler)
    plug(RequireRole, role: "author")
  end

  pipeline :landgrab_validator do
    plug(:accepts, ["json"])
    plug(RegistrationsWeb.PowAuthPlug, otp_app: :registrations)
    plug(Pow.Plug.RequireAuthenticated, error_handler: RegistrationsWeb.PowAuthErrorHandler)
    plug(RequireRole, role: "validator")
  end

  pipeline :landgrab_supervisor do
    plug(:accepts, ["json"])
    plug(RegistrationsWeb.PowAuthPlug, otp_app: :registrations)
    plug(Pow.Plug.RequireAuthenticated, error_handler: RegistrationsWeb.PowAuthErrorHandler)
    plug(RequireRole, role: "validation_supervisor")
  end

  pipeline :landgrab_tester do
    plug(:accepts, ["json"])
    plug(RegistrationsWeb.PowAuthPlug, otp_app: :registrations)
    plug(Pow.Plug.RequireAuthenticated, error_handler: RegistrationsWeb.PowAuthErrorHandler)
    plug(RegistrationsWeb.Plugs.RequireAnyRole, roles: ["validator", "validation_supervisor"])
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

    get("/landgrab-event", LandgrabEventController, :edit, as: :landgrab_event)
    put("/landgrab-event", LandgrabEventController, :update, as: :landgrab_event)

    get("/user-roles", AdminUserRoleController, :index, as: :admin_user_role)
    post("/user-roles", AdminUserRoleController, :create, as: :admin_user_role)
    delete("/user-roles/:id", AdminUserRoleController, :delete, as: :admin_user_role)

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

  scope "/landgrab", RegistrationsWeb.Landgrab, as: :landgrab do
    pipe_through([:pow_api, :pow_api_protected])

    get("/me", MeController, :show)
    get("/event", EventController, :show)
    get("/poles", PoleController, :index)
    get("/poles/:barcode", PoleController, :show)
    get("/attachments/:id", AttachmentController, :show)
    get("/attachments/:id/thumb", AttachmentController, :show_thumb)
    post("/puzzlets/:puzzlet_id/attempts", AttemptController, :create)
    get("/bathrooms", BathroomController, :index)
  end

  scope "/landgrab/drafts", RegistrationsWeb.Landgrab, as: :landgrab_drafts do
    pipe_through([:landgrab_author])

    get("/mine", DraftController, :index)
    post("/poles", DraftController, :create_pole)
    patch("/poles/:id", DraftController, :update_pole)
    delete("/poles/:id", DraftController, :delete_pole)
    post("/poles/:pole_id/attachments", AttachmentController, :create_for_pole)
    post("/puzzlets", DraftController, :create_puzzlet)
    patch("/puzzlets/:id", DraftController, :update_puzzlet)
    delete("/puzzlets/:id", DraftController, :delete_puzzlet)
    post("/puzzlets/:puzzlet_id/attachments", AttachmentController, :create_for_puzzlet)
    delete("/attachments/:id", AttachmentController, :delete)
  end

  scope "/landgrab/bathrooms", RegistrationsWeb.Landgrab, as: :landgrab_bathrooms_author do
    pipe_through([:landgrab_author])

    get("/mine", BathroomController, :mine)
    post("/", BathroomController, :create)
  end

  # PATCH/DELETE allow creator (typically an author) OR a supervisor
  # override. The controller's can_modify? does the actual gate; we just
  # need to be past auth here.
  scope "/landgrab/bathrooms", RegistrationsWeb.Landgrab, as: :landgrab_bathrooms do
    pipe_through([:pow_api, :pow_api_protected])

    patch("/:id", BathroomController, :update)
    delete("/:id", BathroomController, :delete)
  end

  scope "/landgrab/regions", RegistrationsWeb.Landgrab, as: :landgrab_regions do
    pipe_through([:landgrab_author])

    get("/", RegionController, :index)
    post("/", RegionController, :create)
    get("/:id", RegionController, :show)
    patch("/:id", RegionController, :update)
    delete("/:id", RegionController, :delete)
  end

  scope "/landgrab/validation", RegistrationsWeb.Landgrab, as: :landgrab_validation do
    pipe_through([:landgrab_validator])

    get("/mine", ValidationController, :mine)
    patch("/pole-validations/:id", ValidationController, :update_pole_validation)
    patch("/puzzlet-validations/:id", ValidationController, :update_puzzlet_validation)

    post("/pole-validations/:validation_id/comments", ValidationController, :create_pole_comment)
    post("/puzzlet-validations/:validation_id/comments", ValidationController, :create_puzzlet_comment)

    patch("/pole-comments/:id", ValidationController, :update_pole_comment)
    patch("/puzzlet-comments/:id", ValidationController, :update_puzzlet_comment)
    delete("/pole-comments/:id", ValidationController, :delete_pole_comment)
    delete("/puzzlet-comments/:id", ValidationController, :delete_puzzlet_comment)
  end

  scope "/landgrab/test-play", RegistrationsWeb.Landgrab, as: :landgrab_test_play do
    pipe_through([:landgrab_tester])

    post("/sessions", TestPlayController, :create_session)
    get("/sessions", TestPlayController, :list_sessions)
    post("/sessions/:id/end", TestPlayController, :end_session)

    get("/sessions/:session_id/poles", TestPlayController, :list_poles)
    get("/sessions/:session_id/poles/:barcode", TestPlayController, :scan_pole)

    post(
      "/sessions/:session_id/puzzlets/:puzzlet_id/attempts",
      TestPlayController,
      :submit_attempt
    )
  end

  scope "/landgrab/supervision", RegistrationsWeb.Landgrab, as: :landgrab_supervision do
    pipe_through([:landgrab_supervisor])

    get("/dashboard", SupervisionController, :dashboard)
    get("/validators", SupervisionController, :list_validators)
    get("/poles", SupervisionController, :list_poles)
    get("/puzzlets", SupervisionController, :list_puzzlets)

    get("/poles/:id/validations", SupervisionController, :list_pole_validations)
    get("/puzzlets/:id/validations", SupervisionController, :list_puzzlet_validations)

    post("/poles/:id/validations", SupervisionController, :assign_pole)
    post("/puzzlets/:id/validations", SupervisionController, :assign_puzzlet)

    patch("/pole-validations/:id", SupervisionController, :update_pole_validation)
    patch("/puzzlet-validations/:id", SupervisionController, :update_puzzlet_validation)

    patch(
      "/pole-validations/:id/validator",
      SupervisionController,
      :reassign_pole_validation
    )

    patch(
      "/puzzlet-validations/:id/validator",
      SupervisionController,
      :reassign_puzzlet_validation
    )

    delete("/pole-validations/:id", SupervisionController, :unassign_pole_validation)
    delete("/puzzlet-validations/:id", SupervisionController, :unassign_puzzlet_validation)

    patch("/pole-comments/:id", SupervisionController, :update_pole_comment)
    patch("/puzzlet-comments/:id", SupervisionController, :update_puzzlet_comment)

    patch("/poles/:id", SupervisionController, :update_pole)
    patch("/puzzlets/:id", SupervisionController, :update_puzzlet)
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
