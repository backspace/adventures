defmodule RegistrationsWeb.RegistrationController do
  use RegistrationsWeb, :controller
  alias RegistrationsWeb.User

  def new(conn, _params) do
    changeset = User.old_changeset(%User{})

    conn =
      case Application.get_env(:registrations, :registration_closed) do
        true ->
          conn
          |> put_flash(
            :error,
            "Registration is closed; however, you may continue and we will email you"
          )

        _ ->
          conn
      end

    render(conn, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    changeset = User.old_changeset(%User{}, user_params)

    case RegistrationsWeb.Registration.create(changeset, Registrations.Repo) do
      {:ok, user} ->
        messages =
          Registrations.Repo.all(
            from(m in RegistrationsWeb.Message,
              where: m.ready == true,
              select: m,
              order_by: :postmarked_at
            )
          )

        Registrations.Mailer.send_registration(user)
        Registrations.Mailer.send_welcome_email(user.email)

        unless Enum.empty?(messages) do
          Registrations.Mailer.send_backlog(messages, user)
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

    render(conn, "edit.html", user: current_user, changeset: changeset)
  end

  def update(conn, %{"user" => user_params}) do
    current_user = conn.assigns[:current_user_object]
    changeset = User.account_changeset(current_user, user_params)

    session_params = %{
      "email" => current_user.email,
      "password" => user_params["current_password"]
    }

    case RegistrationsWeb.Session.login(session_params, Registrations.Repo) do
      {:ok, _} ->
        case RegistrationsWeb.Registration.update(changeset, Registrations.Repo) do
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

    render(conn, "maybe_delete.html", user: current_user, changeset: changeset)
  end

  def delete(conn, %{"user" => user_params}) do
    current_user = conn.assigns[:current_user_object]
    changeset = User.deletion_changeset(current_user, user_params)

    session_params = %{
      "email" => current_user.email,
      "password" => user_params["current_password"]
    }

    case RegistrationsWeb.Session.login(session_params, Registrations.Repo) do
      {:ok, _} ->
        case RegistrationsWeb.Registration.delete(changeset, Registrations.Repo) do
          {:ok, _} ->
            Registrations.Mailer.send_user_deletion(current_user)

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
