defmodule RegistrationsWeb.InstallController do
  @moduledoc """
  Printable, full-page QR posters for day-of app onboarding — one per
  page, QR huge, caption in the display face. Links come from
  `:onboarding_links` config (set via env per deploy).
  """
  use RegistrationsWeb, :controller

  # Order matters: it's the sequence a walk-up follows on each platform
  # (install the delivery channel first, then the app).
  @posters [
    {:ios_testflight, "iOS · 1 · Install TestFlight"},
    {:ios_install, "iOS · 2 · Install the app"},
    {:android_group, "Android · 1 · Join the group"},
    {:android_install, "Android · 2 · Install the app"}
  ]

  def index(conn, _params) do
    links = Application.get_env(:registrations, :onboarding_links, [])

    posters =
      Enum.map(@posters, fn {key, caption} ->
        url = links[key]
        %{caption: caption, url: (url && String.trim(url)) || "", env: env_var(key)}
      end)

    render(conn, "index.html", posters: posters)
  end

  defp env_var(key), do: "ONBOARDING_#{key |> Atom.to_string() |> String.upcase()}"
end
