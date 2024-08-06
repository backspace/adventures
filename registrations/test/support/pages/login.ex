defmodule Registrations.Pages.Login do
  use Hound.Helpers

  def visit do
    navigate_to("/session/new")
  end

  def fill_email(email) do
    fill_field({:id, "email"}, email)
  end

  def fill_password(password) do
    fill_field({:id, "password"}, password)
  end

  def submit do
    click({:class, "button"})
  end

  def login_as(email, password) do
    Registrations.Pages.Nav.login_link().click

    fill_email(email)
    fill_password(password)
    submit()
  end

  def login_as_admin() do
    login_as("octavia.butler@example.com", "Xenogenesis")
  end

  def click_forgot_password do
    click({:css, "a.forgot"})
  end
end
