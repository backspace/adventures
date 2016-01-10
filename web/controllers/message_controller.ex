defmodule Cr2016site.MessageController do
  use Cr2016site.Web, :controller

  alias Cr2016site.Message

  plug Cr2016site.Plugs.Admin
  plug :scrub_params, "message" when action in [:create, :update]

  def index(conn, _params) do
    messages = Repo.all(Message)
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
        |> redirect(to: message_path(conn, :edit, message))
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
        |> redirect(to: message_path(conn, :edit, message))
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
    |> redirect(to: message_path(conn, :index))
  end

  def deliver(conn, %{"id" => id})do
    message = Repo.get!(Message, id)
    users = Repo.all(Cr2016site.User)

    Enum.each(users, fn(user) -> Cr2016site.Mailer.send_message(message, user) end)

    conn
    |> put_flash(:info, "Message was sent")
    |> redirect(to: message_path(conn, :index))
  end

  def preview(conn, %{"id" => id}) do
    message = Repo.get!(Message, id)

    conn
    |> put_layout({Cr2016site.EmailView, "layout.html"})
    |> render("preview.html", message: message)
  end
end
