defmodule Registrations.Mailer do
  use Swoosh.Mailer, otp_app: :registrations
  import Swoosh.Email
  import RegistrationsWeb.SharedHelpers

  alias RegistrationsWeb.Router
  alias RegistrationsWeb.Endpoint

  @from "b@events.chromatin.ca"

  def send_welcome_email(email) do
    new()
    |> to(email)
    |> from(adventure_from())
    |> subject("[#{phrase("email_title")}] Welcome!")
    |> html_body(welcome_html())
    |> text_body(welcome_text())
    |> deliver
  end

  def send_question(attributes) do
    new()
    |> to(adventure_from())
    |> from(adventure_from())
    |> subject(
      "Question from #{attributes["name"]} <#{attributes["email"]}>: #{attributes["subject"]}"
    )
    |> text_body(attributes["question"])
    |> deliver
  end

  def send_user_changes(user, changes) do
    new()
    |> to(adventure_from())
    |> from(adventure_from())
    |> subject("#{user.email} details changed: #{Enum.join(Map.keys(changes), ", ")}")
    |> text_body(inspect(changes))
    |> deliver
  end

  def send_user_deletion(user) do
    new()
    |> to(adventure_from())
    |> from(adventure_from())
    |> subject("#{user.email} deleted their account")
    |> text_body(inspect(user))
    |> deliver
  end

  def send_registration(user) do
    new()
    |> to(adventure_from())
    |> from(adventure_from())
    |> subject("#{user.email} registered")
    |> text_body("Yes")
    |> deliver
  end

  def send_message(message, user, relationships, team) do
    new()
    |> to(user.email)
    |> from(message_from(message.from_name, message.from_address))
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
    |> from(adventure_from())
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
    |> from(adventure_from())
    |> subject("[#{phrase("email_title")}] Password reset")
    |> html_body(
      "Here is a <a href='#{Router.Helpers.reset_url(Endpoint, :edit, user.recovery_hash)}'>password reset link</a>"
    )
    |> deliver
  end

  defp welcome_html do
    Phoenix.View.render_to_string(
      RegistrationsWeb.EmailView,
      "#{adventure()}-welcome.html",
      %{
        layout: email_layout()
      }
    )
    |> Premailex.to_inline_css()
  end

  defp welcome_text do
    Premailex.to_text(welcome_html())
  end

  defp message_html(message, user, relationships, team) do
    Phoenix.View.render_to_string(RegistrationsWeb.MessageView, "preview.html", %{
      message: message,
      user: user,
      relationships: relationships,
      team: team,
      layout: email_layout()
    })
    |> Premailex.to_inline_css()
  end

  defp message_text(message, user, relationships, team) do
    Premailex.to_text(message_html(message, user, relationships, team))
  end

  defp backlog_html(messages) do
    Phoenix.View.render_to_string(RegistrationsWeb.MessageView, "backlog.html", %{
      messages: messages,
      layout: email_layout()
    })
    |> Premailex.to_inline_css()
  end

  defp backlog_text(messages) do
    Premailex.to_text(backlog_html(messages))
  end

  defp email_layout do
    {RegistrationsWeb.EmailView, "#{adventure()}-layout.html"}
  end

  defp message_from(from_name, from_address) do
    case from_address do
      "" -> @from
      nil -> @from
      _ -> {from_name, from_address}
    end
  end

  defp adventure_from() do
    if RegistrationsWeb.SharedHelpers.is_unmnemonic_devices() do
      "knut@chromatin.ca"
    else
      @from
    end
  end

  def message_from_string(message) do
    case message.from_address do
      "" -> nil
      nil -> nil
      _ -> "From: #{message.from_name} <#{message.from_address}>"
    end
  end
end
