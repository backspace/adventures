defmodule Registrations.Pages.Register do
  @moduledoc false
  alias Wallaby.Browser
  alias Wallaby.Query

  def fill_email(session, email) do
    Browser.fill_in(session, Query.css("#email"), with: email)
  end

  def email_error(session) do
    Browser.text(session, Query.css(".errors .email"))
  end

  def fill_password(session, password) do
    Browser.fill_in(session, Query.css("#password"), with: password)
  end

  def fill_password_confirmation(session, password_confirmation) do
    Browser.fill_in(session, Query.css("#password_confirmation"), with: password_confirmation)
  end

  def password_error(session) do
    Browser.text(session, Query.css(".errors .password"))
  end

  def submit(session) do
    Browser.click(session, Query.css(".button"))
  end
end
