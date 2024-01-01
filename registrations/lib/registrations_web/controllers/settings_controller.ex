defmodule RegistrationsWeb.SettingsController do
  use RegistrationsWeb, :controller

  alias RegistrationsWeb.UnmnemonicDevices.Settings

  plug RegistrationsWeb.Plugs.Admin

  def index(conn, _params) do
    settings = Repo.one(from(s in Settings)) || Repo.insert!(Settings.changeset(%Settings{}, %{}))
    render(conn, "index.html", settings: settings, changeset: Settings.changeset(settings, %{}))
  end

  def update(conn, %{"id" => id, "settings" => settings_params}) do
    settings = Repo.get!(Settings, id)
    changeset = Settings.changeset(settings, settings_params)

    case Repo.update(changeset) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Settings updated successfully.")
        |> redirect(to: Routes.settings_path(conn, :index))

      {:error, changeset} ->
        render(conn, "edit.html", settings: settings, changeset: changeset)
    end
  end
end
