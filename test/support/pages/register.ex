defmodule Cr2016site.Pages.Register do
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

  def password_error do
    visible_text({:css, ".errors .password"})
  end

  def submit do
    click({:class, "btn"})
  end
end
