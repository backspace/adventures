defmodule Registrations.Pages.ForgotPassword do
  @moduledoc false
  alias Wallaby.Browser
  alias Wallaby.Query

  def fill_email(session, email) do
    Browser.fill_in(session, Query.css("#email"), with: email)
  end

  def submit(session) do
    Browser.click(session, Query.css(".button"))
  end
end
