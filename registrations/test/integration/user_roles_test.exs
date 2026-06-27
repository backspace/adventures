defmodule Registrations.Integration.UserRoles do
  @moduledoc false
  use RegistrationsWeb.FeatureCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "landgrab"

  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav
  alias Registrations.Pages.UserRoles

  test "non-admins can't access the roles page", %{session: session} do
    insert(:user, email: "user-roles-regular@example.com", attending: true)

    visit(session, "/")
    Login.login_as(session, "user-roles-regular@example.com", "Xenogenesis")

    refute Nav.roles_link().present?(session)

    visit(session, "/user-roles")
    Nav.assert_error_text(session, "Who are you?")
  end

  test "admin can assign and remove a role", %{session: session} do
    target = insert(:user, email: "user-roles-author@example.com", attending: true)
    insert(:octavia, admin: true)

    visit(session, "/")
    Login.login_as_admin(session)

    Nav.roles_link().click(session)

    refute UserRoles.has_role_for?(session, target.email, "author")

    UserRoles.assign(session, target.email, "author")

    Nav.assert_info_text(session, "Role assigned.")
    assert UserRoles.has_role_for?(session, target.email, "author")

    UserRoles.remove_role(session, target.email, "author")

    Nav.assert_info_text(session, "Role removed.")
    refute UserRoles.has_role_for?(session, target.email, "author")
  end

  test "assigning the same role twice surfaces an error", %{session: session} do
    target = insert(:user, email: "user-roles-validator@example.com", attending: true)
    insert(:octavia, admin: true)

    visit(session, "/")
    Login.login_as_admin(session)

    Nav.roles_link().click(session)

    UserRoles.assign(session, target.email, "validator")
    Nav.assert_info_text(session, "Role assigned.")

    UserRoles.assign(session, target.email, "validator")
    Nav.assert_error_text(session, "User already has that role.")
  end

  test "the roles nav link is visible at all times for admins", %{session: session} do
    insert(:octavia, admin: true)

    visit(session, "/")
    Login.login_as_admin(session)

    assert Nav.roles_link().present?(session)
  end
end
