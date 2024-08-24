defmodule RegistrationsWeb.Plugs.Settings do
  @moduledoc false
  import Plug.Conn

  alias RegistrationsWeb.UnmnemonicDevices.Settings

  def init(options) do
    options
  end

  def call(conn, _) do
    conn = fetch_session(conn)

    adventure_name = Application.get_env(:registrations, :adventure)

    settings =
      case adventure_name do
        "unmnemonic-devices" ->
          Settings
          |> Ecto.Query.first()
          |> Registrations.Repo.one() ||
            %Settings{}

        _ ->
          %Settings{}
      end

    assign(conn, :settings, settings)
  end
end
