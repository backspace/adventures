defmodule AdventureRegistrations.Mailer do
  use Mailgun.Client,
    domain: Application.get_env(:adventure_registrations, :mailgun_domain),
    key: Application.get_env(:adventure_registrations, :mailgun_key),
    mode: Application.get_env(:adventure_registrations, :mailgun_mode),
    test_file_path: Application.get_env(:adventure_registrations, :mailgun_test_file_path)

  alias AdventureRegistrationsWeb.Router
  alias AdventureRegistrationsWeb.Endpoint

  @from "b@events.chromatin.ca"

  def send_welcome_email(email) do
    send_email(
      to: email,
      from: @from,
      subject: "[rendezvous] Welcome!",
      html: welcome_html(),
      text: welcome_text()
    )
  end

  def send_question(attributes) do
    send_email(
      to: "b@events.chromatin.ca",
      from: @from,
      subject:
        "Question from #{attributes["name"]} <#{attributes["email"]}>: #{attributes["subject"]}",
      text: attributes["question"]
    )
  end

  def send_user_changes(user, changes) do
    send_email(
      to: @from,
      from: @from,
      subject: "#{user.email} details changed: #{Enum.join(Map.keys(changes), ", ")}",
      text: inspect(changes)
    )
  end

  def send_user_deletion(user) do
    send_email(
      to: @from,
      from: @from,
      subject: "#{user.email} deleted their account",
      text: inspect(user)
    )
  end

  def send_registration(user) do
    send_email(to: @from, from: @from, subject: "#{user.email} registered", text: "Yes")
  end

  def send_message(message, user, relationships, team) do
    send_email(
      to: user.email,
      from: @from,
      subject: "[rendezvous] #{message.subject}",
      text: message_text(message, user, relationships, team),
      html: message_html(message, user, relationships, team)
    )
  end

  def send_backlog(messages, user) do
    subject =
      case length(messages) do
        1 -> "Message sent before you registered"
        _ -> "Messages sent before you registered"
      end

    send_email(
      to: user.email,
      from: @from,
      subject: "[rendezvous] #{subject}",
      text: backlog_text(messages),
      html: backlog_html(messages)
    )
  end

  def send_password_reset(user) do
    send_email(
      to: user.email,
      from: @from,
      subject: "[rendezvous] Password reset",
      html:
        "Here is a <a href='#{Router.Helpers.reset_url(Endpoint, :edit, user.recovery_hash)}'>password reset link"
    )
  end

  defp welcome_html do
    Phoenix.View.render_to_string(AdventureRegistrationsWeb.EmailView, "welcome.html", %{
      layout: {AdventureRegistrationsWeb.EmailView, "layout.html"}
    })
  end

  defp welcome_text do
    File.write(
      "/tmp/email.html",
      Phoenix.View.render_to_string(AdventureRegistrationsWeb.EmailView, "welcome.html", %{})
    )

    Porcelain.exec("ruby", ["lib/adventure_registrations/convert-html-to-text.rb", AdventureRegistrationsWeb.Endpoint.url()]).out
  end

  defp message_html(message, user, relationships, team) do
    Phoenix.View.render_to_string(AdventureRegistrationsWeb.MessageView, "preview.html", %{
      message: message,
      user: user,
      relationships: relationships,
      team: team,
      layout: {AdventureRegistrationsWeb.EmailView, "layout.html"}
    })
  end

  defp message_text(message, user, relationships, team) do
    html =
      Phoenix.View.render_to_string(AdventureRegistrationsWeb.MessageView, "preview.html", %{
        message: message,
        user: user,
        relationships: relationships,
        team: team
      })

    File.write("/tmp/email.html", html)

    Porcelain.exec("ruby", ["lib/adventure_registrations/convert-html-to-text.rb", AdventureRegistrationsWeb.Endpoint.url()]).out
  end

  defp backlog_html(messages) do
    Phoenix.View.render_to_string(AdventureRegistrationsWeb.MessageView, "backlog.html", %{
      messages: messages,
      layout: {AdventureRegistrationsWeb.EmailView, "layout.html"}
    })
  end

  defp backlog_text(messages) do
    html =
      Phoenix.View.render_to_string(AdventureRegistrationsWeb.MessageView, "backlog.html", %{
        messages: messages
      })

    File.write("/tmp/email.html", html)

    Porcelain.exec("ruby", ["lib/adventure_registrations/convert-html-to-text.rb", AdventureRegistrationsWeb.Endpoint.url()]).out
  end
end
