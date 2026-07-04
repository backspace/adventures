import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :logger, :console, format: "[$level] $message\n"

config :mix_test_watch,
  exclude: [~r/priv\/repo\/migrations\/.*/]

config :phoenix, :stacktrace_depth, 20

config :registrations, Registrations.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "registrations_dev",
  hostname: "localhost",
  pool_size: 10

config :registrations, RegistrationsWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  cache_static_lookup: false,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:registrations, ~w(--sourcemap=inline --watch)]},
    sass: {DartSass, :install_and_run, [:registrations, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :registrations, RegistrationsWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{web/views/.*(ex)$},
      ~r{web/templates/.*(eex)$}
    ]
  ]

# Do not include metadata nor timestamps in development logs

# Set a higher stacktrace during development.
# Do not configure such in production as keeping
# and calculating stacktraces is usually expensive.

# Configure your database
config :registrations,
  request_confirmation: true

config :swoosh, :api_client, Swoosh.ApiClient.Hackney

# Optional local HTTPS listener. Activate by exporting
# `LOCAL_HOSTNAME=<host>.<tailnet>.ts.net` (or any hostname you have
# a real cert for) and dropping `<hostname>.crt` / `<hostname>.key`
# at `LOCAL_CERT_DIR` (defaults to `~/.local/share/certs`). Simplest
# way if you're on Tailscale: `tailscale cert <host>.<tailnet>.ts.net`.
# Useful for testing iOS App Transport Security and OAuth flows
# against a real cert without deploying.
#
# The block is a no-op when either the env var is unset or the cert
# files are missing, so Phoenix keeps serving HTTP-only in that case.
if hostname = System.get_env("LOCAL_HOSTNAME") do
  cert_dir = System.get_env("LOCAL_CERT_DIR") || Path.expand("~/.local/share/certs")
  tls_cert = Path.join(cert_dir, "#{hostname}.crt")
  tls_key = Path.join(cert_dir, "#{hostname}.key")

  if File.exists?(tls_cert) and File.exists?(tls_key) do
    config :registrations, RegistrationsWeb.Endpoint,
      https: [
        ip: {0, 0, 0, 0},
        port: 4443,
        keyfile: tls_key,
        certfile: tls_cert,
        # Cowboy 2.10 advertises h2 in ALPN by default (see
        # `Plug.Cowboy.child_spec/1` — it `Keyword.put_new`s
        # `["h2", "http/1.1"]`). Chrome tears down h2 streams for
        # Phoenix's static assets with `ERR_HTTP2_PROTOCOL_ERROR`
        # over that pairing, so restrict local dev to 1.1. Prod
        # sits behind Coolify's reverse proxy which handles h2
        # separately, so this override is dev-only.
        alpn_preferred_protocols: ["http/1.1"],
        next_protocols_advertised: ["http/1.1"]
      ],
      # Phoenix uses `url:` to build URLs (OAuth `redirect_uri`, email
      # links, og:image, etc.). Point it at the same hostname the
      # cert covers so those match the SAN when the phone hits them.
      url: [host: hostname, port: 4443, scheme: "https"]

    # `base_url` is what the layout renders in `og:*` meta tags and
    # what `SessionExchangeController.mint` builds its return URL
    # from. Overrides `http://example.com` from config.exs.
    config :registrations, base_url: "https://#{hostname}:4443"
  end
end

if File.exists?("config/dev.secret.exs") do
  import_config "dev.secret.exs"
end
