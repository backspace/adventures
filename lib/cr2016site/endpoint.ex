defmodule Cr2016site.Endpoint do
  use Phoenix.Endpoint, otp_app: :cr2016site

  socket "/socket", Cr2016site.UserSocket

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/", from: :cr2016site, gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt),
    headers: %{"Access-Control-Allow-Origin" => "*", "X-Jorts" => "Jants"}

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session,
    store: :cookie,
    key: "_cr2016site_uuid_key",
    signing_salt: "dBMzbbb9",
    max_age: 60*60*24*365

  plug Cr2016site.Router
end
