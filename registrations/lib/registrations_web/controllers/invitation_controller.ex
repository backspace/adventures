defmodule RegistrationsWeb.InvitationController do
  use RegistrationsWeb, :controller

  alias PowInvitation.Phoenix.Mailer
  alias PowInvitation.Plug

  def create(conn, %{"user" => user_params}) do
    case Plug.create_user(conn, user_params) do
      {:ok, user, conn} ->
        deliver_email(conn, user)

        conn
        |> put_flash(:info, "Invitation sent")
        |> redirect(to: Routes.user_path(conn, :edit))

      {:error, changeset, conn} ->
        conn
        |> assign(:changeset, changeset)
        |> assign(:action, Routes.invitation_path(conn, :create))
        |> render("new.html")
    end
  end

  defp deliver_email(conn, user) do
    token = Plug.sign_invitation_token(conn, user)
    url = Routes.pow_invitation_invitation_url(conn, :edit, token)
    invited_by = Pow.Plug.current_user(conn)
    email = Mailer.invitation(conn, user, invited_by, url)

    Pow.Phoenix.Mailer.deliver(conn, email)
  end
end
