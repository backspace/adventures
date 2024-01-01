defmodule RegistrationsWeb.PageController do
  use RegistrationsWeb, :controller

  def index(conn, _params) do
    adventure_name = Application.get_env(:registrations, :adventure)
    render(conn, "#{adventure_name}.html")
  end

  def questions(conn, %{"question" => question_params}) do
    Registrations.Mailer.send_question(question_params)

    conn
    |> put_flash(:info, "Your question has been submitted.")
    |> redirect(to: "/")
  end
end
