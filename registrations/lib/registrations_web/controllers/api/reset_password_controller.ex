defmodule RegistrationsWeb.ApiResetPasswordController do
  @moduledoc """
  Triggers a password-reset email over the JSON API, mirroring the web
  PowResetPassword flow (see
  `PowResetPassword.Phoenix.ResetPasswordController`).

  This exists so the app can offer a native "forgot password" form instead
  of hosting the site's pages in a WebView: after the web reset form is
  submitted, Pow redirects to the login page, whose "Sign in with Google"
  button trips Google's `disallowed_useragent` block inside a WebView. A
  native form + this endpoint sidestep the WebView (and that button)
  entirely. The "choose a new password" step still happens through the
  emailed link, which opens in the system browser.
  """
  use RegistrationsWeb, :controller

  alias PowResetPassword.Phoenix.Mailer
  alias PowResetPassword.Plug

  @doc """
  Sends a reset email for the given address. Always responds `{ok: true}`
  whether or not the email matches an account, so the API doesn't leak
  which addresses are registered (matching Pow's default
  enumeration-prevention behaviour).
  """
  def create(conn, %{"user" => %{"email" => _email} = user_params}) do
    case Plug.create_reset_token(conn, user_params) do
      {:ok, %{token: token, user: user}, conn} ->
        deliver_email(conn, user, token)
        json(conn, %{ok: true})

      {:error, _changeset, conn} ->
        json(conn, %{ok: true})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{code: "invalid_params"}})
  end

  defp deliver_email(conn, user, token) do
    url = Routes.pow_reset_password_reset_password_url(conn, :edit, token)
    email = Mailer.reset_password(conn, user, url)
    Pow.Phoenix.Mailer.deliver(conn, email)
  end
end
