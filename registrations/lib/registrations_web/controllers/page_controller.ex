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

    hide_waitlist = Application.get_env(:registrations, :hide_waitlist, false)

    adventure_name = Application.get_env(:registrations, :adventure)
    render(conn, "#{adventure_name}.html", placeholder: placeholder, hide_waitlist: hide_waitlist)
  end

  def questions(conn, %{"question" => question_params}) do
    Registrations.Mailer.send_question(question_params)

    conn
    |> put_flash(:info, "Your question has been submitted.")
    |> redirect(to: "/")
  end

  def waitlist(conn, %{"waitlist" => waitlist_params}) do
    spam_strings = Application.get_env(:registrations, :spam_strings, [])

    email = waitlist_params["email"]
    question = waitlist_params["question"]

    flash_message =
      if EmailChecker.Check.Format.valid?(email) do
        if contains_spam?(email, question, spam_strings) do
          Sentry.capture_message("Spam submission",
            level: :warning,
            extra: %{email: email, question: question}
          )
        else
          Registrations.Mailer.waitlist_email(email, question)
        end

        "we’ll let you know when registration opens"
      else
        "was that an email address?"
      end

    conn
    |> put_flash(:info, flash_message)
    |> redirect(to: Routes.page_path(conn, :index))
  end

  defp contains_spam?(email, question, spam_strings) do
    Enum.any?(spam_strings, fn spam_string ->
      String.contains?(String.downcase(email), String.downcase(spam_string)) ||
        String.contains?(String.downcase(question), String.downcase(spam_string))
    end)
  end
end
