defmodule AdventureRegistrationsWeb.RegistrationController do
  use AdventureRegistrationsWeb, :controller
  alias AdventureRegistrationsWeb.User

  def new(conn, _params) do
    changeset = User.changeset(%User{})

    conn = case Application.get_env(:adventure_registrations, :registration_closed) do
      true ->
        conn
        |> put_flash(:error, "Registration is closed; however, you may continue and we will email you")
      _ ->
        conn
    end

    render conn, changeset: changeset
  end

  def create(conn, %{"user" => user_params}) do
    changeset = User.changeset(%User{}, user_params)

    case AdventureRegistrationsWeb.Registration.create(changeset, AdventureRegistrations.Repo) do
      {:ok, user} ->
        messages = AdventureRegistrations.Repo.all(
          from m in AdventureRegistrationsWeb.Message,
            where: m.ready == true,
          select: m,
          order_by: :postmarked_at
        )

        AdventureRegistrations.Mailer.send_registration(user)
        AdventureRegistrations.Mailer.send_welcome_email(user.email)

        unless Enum.empty? messages do
          AdventureRegistrations.Mailer.send_backlog(messages, user)
        end

        conn
        |> put_session(:current_user, user.id)
        |> put_flash(:info, "Your account was created")
        |> redirect(to: Routes.user_path(conn, :edit))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Unable to create account")
        |> render("new.html", changeset: changeset)
    end
  end

  def edit(conn, _) do
    current_user = conn.assigns[:current_user_object]
    changeset = User.account_changeset(current_user)

    render conn, "edit.html", user: current_user, changeset: changeset
  end

  def update(conn, %{"user" => user_params}) do
    current_user = conn.assigns[:current_user_object]
    changeset = User.account_changeset(current_user, user_params)

    session_params = %{"email" => current_user.email, "password" => user_params["current_password"]}

    case AdventureRegistrationsWeb.Session.login(session_params, AdventureRegistrations.Repo) do
      {:ok, _} ->
        case AdventureRegistrationsWeb.Registration.update(changeset, AdventureRegistrations.Repo) do
          {:ok, _} ->
            conn
            |> put_flash(:info, "Your password has been changed")
            |> redirect(to: Routes.user_path(conn, :edit))
          {:error, changeset} ->
            conn
            |> put_flash(:error, "New passwords must match")
            |> render("edit.html", changeset: changeset)
        end
      :error ->
        conn
        |> put_flash(:error, "Please enter your current password")
        |> render("edit.html", changeset: changeset)
    end
  end

  # FIXME 😳
  def maybe_delete(conn, _) do
    current_user = conn.assigns[:current_user_object]
    changeset = User.deletion_changeset(current_user)

    render conn, "maybe_delete.html", user: current_user, changeset: changeset
  end

  def delete(conn, %{"user" => user_params}) do
    current_user = conn.assigns[:current_user_object]
    changeset = User.deletion_changeset(current_user, user_params)

    session_params = %{"email" => current_user.email, "password" => user_params["current_password"]}

    case AdventureRegistrationsWeb.Session.login(session_params, AdventureRegistrations.Repo) do
      {:ok, _} ->
        case AdventureRegistrationsWeb.Registration.delete(changeset, AdventureRegistrations.Repo) do
          {:ok, _} ->
            AdventureRegistrations.Mailer.send_user_deletion(current_user)

            conn
            |> put_flash(:info, "Your account has been deleted 😧")
            |> redirect(to: Routes.page_path(conn, :index))
          {:error, changeset} ->
            conn
            |> put_flash(:error, "Something went wrong!")
            |> render("maybe_delete.html", changeset: changeset)
        end
      :error ->
        conn
        |> put_flash(:error, "Your password did not match")
        |> render("maybe_delete.html", changeset: changeset)
    end
  end
end
