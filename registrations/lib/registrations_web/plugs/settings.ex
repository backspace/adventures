defmodule RegistrationsWeb.Plugs.Settings do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _) do
    conn = fetch_session(conn)

    adventure_name = Application.get_env(:registrations, :adventure)

    settings =
      case adventure_name do
        "unmnemonic-devices" ->
          Ecto.Query.first(RegistrationsWeb.UnmnemonicDevices.Settings)
          |> Registrations.Repo.one() ||
            %RegistrationsWeb.UnmnemonicDevices.Settings{}

        _ ->
          %RegistrationsWeb.UnmnemonicDevices.Settings{}
      end

    assign(conn, :settings, settings)
  end
end
