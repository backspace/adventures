defmodule Cr2016site.Mailer do
  use Mailgun.Client, domain: Application.get_env(:cr2016site, :mailgun_domain),
                      key: Application.get_env(:cr2016site, :mailgun_key),
                      mode: Application.get_env(:cr2016site, :mailgun_mode),
                      test_file_path: Application.get_env(:cr2016site, :mailgun_test_file_path)

  alias Cr2016site.Router
  alias Cr2016site.Endpoint

  @from "b@events.chromatin.ca"

  def send_welcome_email(email) do
    send_email to: email,
               from: @from,
               subject: "[rendezvous] Welcome!",
               html: welcome_html,
               text: "Yes?"
  end

  def send_question(attributes) do
    send_email to: "b@events.chromatin.ca",
               from: @from,
               subject: "Question from #{attributes["name"]} <#{attributes["email"]}>: #{attributes["subject"]}",
               text: attributes["question"]
  end

  def send_user_changes(user, changes) do
    send_email to: @from,
               from: @from,
               subject: "#{user.email} details changed: #{Enum.join(Map.keys(changes), ", ")}",
               text: inspect(changes)
  end

  def send_registration(user) do
    send_email to: @from, from: @from, subject: "#{user.email} registered", text: "Yes"
  end

  def send_message(message, user) do
    send_email to: user.email, from: @from, subject: "[rendezvous] #{message.subject}", text: message.content, html: message_html(message)
  end

  def send_backlog(messages, user) do
    message_bodies = Enum.map(messages, fn(message) ->
      "Subject: #{message.subject}\n\n#{message.content}"
    end)

    body = "These messages were sent before you registered.\n\n#{message_bodies}"

    send_email to: user.email, from: @from, subject: "[rendezvous] Messages sent before you registered", text: body
  end

  def send_password_reset(user) do
    send_email to: user.email,
               from: @from,
               subject: "[rendezvous] Password reset",
               html: "Here is a <a href='#{Router.Helpers.reset_url(Endpoint, :edit, user.recovery_hash)}'>password reset link"
  end

  defp welcome_html do
    Phoenix.View.render_to_string(Cr2016site.EmailView, "welcome.html", %{layout: {Cr2016site.EmailView, "layout.html"}})
  end

  defp message_html(message) do
    message.rendered_content
  end
end
