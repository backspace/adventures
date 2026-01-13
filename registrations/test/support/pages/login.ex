defmodule Registrations.Pages.Login do
  @moduledoc false
  alias Wallaby.Browser
  alias Wallaby.Query

  def visit(session) do
    Browser.visit(session, "/session/new")
  end

  def fill_email(session, email) do
    Browser.fill_in(session, Query.css("#email"), with: email)
  end

  def fill_password(session, password) do
    Browser.fill_in(session, Query.css("#password"), with: password)
  end

  def submit(session) do
    Browser.click(session, Query.css(".button"))
  end

  def login_as(session, email, password) do
    session
    |> Registrations.Pages.Nav.login_link().click()
    |> fill_email(email)
    |> fill_password(password)
    |> submit()
  end

  def login_as_admin(session) do
    login_as(session, "octavia.butler@example.com", "Xenogenesis")
  end

  def click_forgot_password(session) do
    Browser.click(session, Query.css("a.forgot"))
  end
end
