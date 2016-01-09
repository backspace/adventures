defmodule Cr2016site.Pages.ForgotPassword do
  use Hound.Helpers

  def fill_email(email) do
    fill_field({:id, "email"}, email)
  end

  def submit do
    click({:class, "button"})
  end
end
