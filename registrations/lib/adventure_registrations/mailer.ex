defmodule AdventureRegistrations.Mailer do
  use Swoosh.Mailer, otp_app: :adventure_registrations
  import Swoosh.Email
  import AdventureRegistrationsWeb.SharedHelpers

  alias AdventureRegistrationsWeb.Router
  alias AdventureRegistrationsWeb.Endpoint

  @from "b@events.chromatin.ca"

  def send_welcome_email(email) do
    new()
    |> to(email)
    |> from(@from)
    |> subject("[#{phrase("email_title")}] Welcome!")
    |> html_body(welcome_html())
    |> text_body(welcome_text())
    |> deliver
  end

  def send_question(attributes) do
    new()
    |> to("b@events.chromatin.ca")
    |> from(@from)
    |> subject(
      "Question from #{attributes["name"]} <#{attributes["email"]}>: #{attributes["subject"]}"
    )
    |> text_body(attributes["question"])
    |> deliver
  end

  def send_user_changes(user, changes) do
    new()
    |> to(@from)
    |> from(@from)
    |> subject("#{user.email} details changed: #{Enum.join(Map.keys(changes), ", ")}")
    |> text_body(inspect(changes))
    |> deliver
  end

  def send_user_deletion(user) do
    new()
    |> to(@from)
    |> from(@from)
    |> subject("#{user.email} deleted their account")
    |> text_body(inspect(user))
    |> deliver
  end

  def send_registration(user) do
    new()
    |> to(@from)
    |> from(@from)
    |> subject("#{user.email} registered")
    |> text_body("Yes")
    |> deliver
  end

  def send_message(message, user, relationships, team) do
    new()
    |> to(user.email)
    |> from(@from)
    |> subject("[#{phrase("email_title")}] #{message.subject}")
    |> text_body(message_text(message, user, relationships, team))
    |> html_body(message_html(message, user, relationships, team))
    |> deliver
  end

  def send_backlog(messages, user) do
    subject =
      case length(messages) do
        1 -> "Message sent before you registered"
        _ -> "Messages sent before you registered"
      end

    new()
    |> to(user.email)
    |> from(@from)
    |> subject("[#{phrase("email_title")}] #{subject}")
    |> text_body(backlog_text(messages))
    |> html_body(backlog_html(messages))
    |> deliver
  end

  @spec send_password_reset(atom | %{:email => any, :recovery_hash => any, optional(any) => any}) ::
          {:error, any} | {:ok, any}
  def send_password_reset(user) do
    new()
    |> to(user.email)
    |> from(@from)
    |> subject("[#{phrase("email_title")}] Password reset")
    |> html_body(
      "Here is a <a href='#{Router.Helpers.reset_url(Endpoint, :edit, user.recovery_hash)}'>password reset link</a>"
    )
    |> deliver
  end

  defp welcome_html do
    Phoenix.View.render_to_string(
      AdventureRegistrationsWeb.EmailView,
      "#{adventure()}-welcome.html",
      %{
        layout: email_layout()
      }
    )
  end

  defp welcome_text do
    Premailex.to_text(welcome_html())
  end

  defp message_html(message, user, relationships, team) do
    Phoenix.View.render_to_string(AdventureRegistrationsWeb.MessageView, "preview.html", %{
      message: message,
      user: user,
      relationships: relationships,
      team: team,
      layout: email_layout()
    })
  end

  defp message_text(message, user, relationships, team) do
    Premailex.to_text(message_html(message, user, relationships, team))
  end

  defp backlog_html(messages) do
    Phoenix.View.render_to_string(AdventureRegistrationsWeb.MessageView, "backlog.html", %{
      messages: messages,
      layout: email_layout()
    })
  end

  defp backlog_text(messages) do
    Premailex.to_text(backlog_html(messages))
  end

  defp email_layout do
    {AdventureRegistrationsWeb.EmailView, "#{adventure()}-layout.html"}
  end
end
