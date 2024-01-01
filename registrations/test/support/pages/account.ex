defmodule Registrations.Pages.Account do
  use Hound.Helpers

  def fill_current_password(password) do
    fill_field({:id, "current_password"}, password)
  end

  def fill_new_password(password) do
    fill_field({:id, "new_password"}, password)
  end

  def fill_new_password_confirmation(password) do
    fill_field({:id, "new_password_confirmation"}, password)
  end

  def submit do
    click({:class, "button"})
  end
end
