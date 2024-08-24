defmodule Registrations.Pages.ForgotPassword do
  @moduledoc false
  use Hound.Helpers

  def fill_email(email) do
    fill_field({:id, "email"}, email)
  end

  def submit do
    click({:class, "button"})
  end
end
