defmodule AdventureRegistrationsWeb.PageController do
  use AdventureRegistrationsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def questions(conn, %{"question" => question_params}) do
    AdventureRegistrations.Mailer.send_question(question_params)

    conn
    |> put_flash(:info, "Your question has been submitted.")
    |> redirect(to: "/")
  end
end
