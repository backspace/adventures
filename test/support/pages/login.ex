defmodule Cr2016site.Pages.Login do
  use Hound.Helpers

  def fill_email(email) do
    fill_field({:id, "email"}, email)
  end

  def fill_password(password) do
    fill_field({:id, "password"}, password)
  end

  def submit do
    click({:class, "btn"})
  end
end
