defmodule AdventureRegistrationsWeb.PageController do
  use AdventureRegistrationsWeb, :controller

  def index(conn, _params) do
    adventure_name = Application.get_env(:adventure_registrations, :adventure);

    settings = case adventure_name do
      "unmnemonic-devices" ->
        (Ecto.Query.first(AdventureRegistrationsWeb.UnmnemonicDevices.Settings) |> Repo.one()) || %AdventureRegistrationsWeb.UnmnemonicDevices.Settings{}

      _ ->
        %AdventureRegistrationsWeb.UnmnemonicDevices.Settings{}
    end

    render(conn, "#{adventure_name}.html", settings: settings)
  end

  def questions(conn, %{"question" => question_params}) do
    AdventureRegistrations.Mailer.send_question(question_params)

    conn
    |> put_flash(:info, "Your question has been submitted.")
    |> redirect(to: "/")
  end
end
