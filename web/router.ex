defmodule Cr2016site.Router do
  use Cr2016site.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Cr2016site do
    pipe_through :browser # Use the default browser stack

    resources "/registrations", RegistrationController, only: [:new, :create]

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", Cr2016site do
  #   pipe_through :api
  # end
end
