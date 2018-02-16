defmodule Cr2016site.Txter do
  import Cr2016site.Router.Helpers

  def send_confirmation_txt(user) do
    sid = Application.get_env(:cr2016site, :twilio_sid)
    token = Application.get_env(:cr2016site, :twilio_token)
    twilio_number = Application.get_env(:cr2016site, :twilio_number)

    HTTPoison.post(
      "https://#{sid}:#{token}@api.twilio.com/2010-04-01/Accounts/#{sid}/Messages",
      {:form, [
        {"From", twilio_number},
        {"To", "+1#{user.number}"},
        {"Body", "txtbeyond confirmation code: #{user.txt_confirmation_sent}\n\nConfirm at #{user_url(Cr2016site.Endpoint, :confirm, user.id, confirmation: user.txt_confirmation_sent)}"}
      ]})
  end
end
