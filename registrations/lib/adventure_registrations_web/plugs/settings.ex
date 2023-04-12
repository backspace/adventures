defmodule AdventureRegistrationsWeb.Plugs.Settings do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _) do
    conn = fetch_session(conn)

    adventure_name = Application.get_env(:adventure_registrations, :adventure)

    settings =
      case adventure_name do
        "unmnemonic-devices" ->
          Ecto.Query.first(AdventureRegistrationsWeb.UnmnemonicDevices.Settings)
          |> AdventureRegistrations.Repo.one() ||
            %AdventureRegistrationsWeb.UnmnemonicDevices.Settings{}

        _ ->
          %AdventureRegistrationsWeb.UnmnemonicDevices.Settings{}
      end

    assign(conn, :settings, settings)
  end
end
