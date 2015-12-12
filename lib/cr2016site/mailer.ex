defmodule Cr2016site.Mailer do
  use Mailgun.Client, domain: Application.get_env(:cr2016site, :mailgun_domain),
                      key: Application.get_env(:cr2016site, :mailgun_key),
                      mode: Application.get_env(:cr2016site, :mailgun_mode),
                      test_file_path: Application.get_env(:cr2016site, :mailgun_test_file_path)

  @from "b@events.chromatin.ca"

  def send_welcome_email(email) do
    send_email to: email,
               from: @from,
               subject: "Welcome!",
               html: "Is it <strong>true</strong> that you are welcome?",
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
    send_email to: user.email, from: @from, subject: "[rendezvous] #{message.subject}", text: message.content
  end
end
