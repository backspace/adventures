defmodule Cr2016siteWeb.PageController do
  use Cr2016siteWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def questions(conn, %{"question" => question_params}) do
    Cr2016site.Mailer.send_question(question_params)

    conn
    |> put_flash(:info, "Your question has been submitted.")
    |> redirect(to: "/")
  end
end
