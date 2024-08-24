defmodule Registrations.Pages.Register do
  @moduledoc false
  use Hound.Helpers

  def fill_email(email) do
    fill_field({:id, "email"}, email)
  end

  def email_error do
    visible_text({:css, ".errors .email"})
  end

  def fill_password(password) do
    fill_field({:id, "password"}, password)
  end

  def fill_password_confirmation(password_confirmation) do
    fill_field({:id, "password_confirmation"}, password_confirmation)
  end

  def password_error do
    visible_text({:css, ".errors .password"})
  end

  def submit do
    click({:class, "button"})
  end
end
