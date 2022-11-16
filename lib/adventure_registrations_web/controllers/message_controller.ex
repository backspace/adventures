defmodule AdventureRegistrationsWeb.MessageController do
  use AdventureRegistrationsWeb, :controller

  alias AdventureRegistrationsWeb.Message

  plug(AdventureRegistrationsWeb.Plugs.Admin)
  plug(:scrub_params, "message" when action in [:create, :update])

  def index(conn, _params) do
    messages = Repo.all(Message |> Ecto.Query.order_by(:postmarked_at))
    render(conn, "index.html", messages: messages)
  end

  def new(conn, _params) do
    changeset = Message.changeset(%Message{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"message" => message_params}) do
    changeset = Message.changeset(%Message{}, message_params)

    case Repo.insert(changeset) do
      {:ok, message} ->
        conn
        |> put_flash(:info, "Message created successfully.")
        |> redirect(to: Routes.message_path(conn, :edit, message))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    message = Repo.get!(Message, id)
    changeset = Message.changeset(message)
    render(conn, "edit.html", message: message, changeset: changeset)
  end

  def update(conn, %{"id" => id, "message" => message_params}) do
    message = Repo.get!(Message, id)
    changeset = Message.changeset(message, message_params)

    case Repo.update(changeset) do
      {:ok, message} ->
        conn
        |> put_flash(:info, "Message updated successfully.")
        |> redirect(to: Routes.message_path(conn, :edit, message))

      {:error, changeset} ->
        render(conn, "edit.html", message: message, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    message = Repo.get!(Message, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(message)

    conn
    |> put_flash(:info, "Message deleted successfully.")
    |> redirect(to: Routes.message_path(conn, :index))
  end

  def deliver(conn, %{"id" => id}) do
    message = Repo.get!(Message, id)
    users = Repo.all(AdventureRegistrationsWeb.User)
    teams = Repo.all(AdventureRegistrationsWeb.Team)

    Enum.each(users, fn user ->
      relationships = AdventureRegistrationsWeb.TeamFinder.relationships(user, users)

      team = Enum.find(teams, fn team -> Enum.member?(team.user_ids, user.id) end)

      AdventureRegistrations.Mailer.send_message(message, user, relationships, team)
    end)

    conn
    |> put_flash(:info, "Message was sent")
    |> redirect(to: Routes.message_path(conn, :index))
  end

  def preview(conn, %{"id" => id}) do
    message = Repo.get!(Message, id)

    conn
    |> put_layout({AdventureRegistrationsWeb.EmailView, "layout.html"})
    |> render("preview.html", message: message)
  end
end
