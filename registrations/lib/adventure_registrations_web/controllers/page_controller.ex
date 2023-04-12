defmodule AdventureRegistrationsWeb.PageController do
  use AdventureRegistrationsWeb, :controller

  def index(conn, _params) do
    adventure_name = Application.get_env(:adventure_registrations, :adventure)
    render(conn, "#{adventure_name}.html")
  end

  def questions(conn, %{"question" => question_params}) do
    AdventureRegistrations.Mailer.send_question(question_params)

    conn
    |> put_flash(:info, "Your question has been submitted.")
    |> redirect(to: "/")
  end
end
