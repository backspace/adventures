defmodule RegistrationsWeb.PageController do
  use RegistrationsWeb, :controller

  require Logger

  def index(conn, _params) do
    placeholder =
      case {conn.query_params["placeholder"], Application.get_env(:registrations, :placeholder, false),
            RegistrationsWeb.Session.logged_in?(conn)} do
        {"true", _, _} ->
          true

        {"false", _, _} ->
          false

        {_, true, true} ->
          false

        {_, true, _} ->
          true

        {_, false, _} ->
          false
      end

    adventure_name = Application.get_env(:registrations, :adventure)
    render(conn, "#{adventure_name}.html", placeholder: placeholder)
  end

  def questions(conn, %{"question" => question_params}) do
    Registrations.Mailer.send_question(question_params)

    conn
    |> put_flash(:info, "Your question has been submitted.")
    |> redirect(to: "/")
  end

  def waitlist(conn, %{"waitlist" => waitlist_params}) do
    email = waitlist_params["email"]
    question = waitlist_params["question"]

    flash_message =
      if EmailChecker.Check.Format.valid?(email) do
        Registrations.Mailer.waitlist_email(email, question)

        "we’ll let you know when registration opens"
      else
        "was that an email address?"
      end

    conn
    |> put_flash(:info, flash_message)
    |> redirect(to: Routes.page_path(conn, :index))
  end
end
