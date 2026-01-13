defmodule Registrations.Pages.Account do
  @moduledoc false
  alias Wallaby.Browser
  alias Wallaby.Query

  def fill_current_password(session, password) do
    Browser.fill_in(session, Query.css("#current_password"), with: password)
  end

  def fill_new_password(session, password) do
    Browser.fill_in(session, Query.css("#new_password"), with: password)
  end

  def fill_new_password_confirmation(session, password) do
    Browser.fill_in(session, Query.css("#new_password_confirmation"), with: password)
  end

  def submit(session) do
    Browser.click(session, Query.css(".button"))
  end
end
