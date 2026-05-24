defmodule Registrations.Pages.UserRoles do
  @moduledoc false
  alias Wallaby.Browser
  alias Wallaby.Query

  def visit(session) do
    Browser.visit(session, "/user-roles")
  end

  def has_user_row?(session, email) do
    Browser.has?(session, Query.xpath("//td[contains(., '#{email}')]"))
  end

  def has_role_for?(session, email, role) do
    selector =
      "//td[contains(., '#{email}')]/following-sibling::td//span[contains(., '#{role}')]"

    Browser.has?(session, Query.xpath(selector))
  end

  def assign(session, user_email, role) do
    # Find the option in the user select by its text content (email substring)
    # and the role option by exact text. Both selects use native HTML <select>.
    user_option =
      Query.xpath(
        "//select[@id='user_id']/option[contains(text(), '#{user_email}')]"
      )

    role_option = Query.xpath("//select[@id='role']/option[text()='#{role}']")

    session
    |> Browser.click(user_option)
    |> Browser.click(role_option)
    |> Browser.click(Query.button("Assign"))
  end

  def remove_role(session, email, role) do
    selector =
      "//td[contains(., '#{email}')]/following-sibling::td//span[contains(., '#{role}')]/a"

    Browser.click(session, Query.xpath(selector))
  end
end
