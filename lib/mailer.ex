defmodule Cr2016site.Mailer do
  use Mailgun.Client, domain: Application.get_env(:cr2016site, :mailgun_domain),
                      key: Application.get_env(:cr2016site, :mailgun_key),
                      mode: Application.get_env(:cr2016site, :mailgun_mode),
                      test_file_path: Application.get_env(:cr2016site, :mailgun_test_file_path)

  @from "b@rendezvous.chromatin.ca"

  def send_welcome_email(email) do
    send_email to: email,
               from: @from,
               subject: "Welcome!",
               html: "Is it <strong>true</strong> that you are welcome?",
               text: "Yes?"
  end
end
