defmodule RegistrationsWeb.Landgrab.OrganiserMessageController do
  @moduledoc """
  Supervisor-only compose/send for storyline messages from the
  organisers (Sabuk / Sabuk's assistant) to all teams. Prewritten
  messages are drafts (`sent_at` nil) waiting for their moment;
  on-the-spot ones are created with `"send" => true` and go out
  immediately.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab

  def index(conn, _params) do
    json(conn, %{messages: Enum.map(Landgrab.list_organiser_messages(), &render_message/1)})
  end

  def create(conn, params) do
    user = Pow.Plug.current_user(conn)

    attrs = %{
      body: params["body"],
      sender_name: params["sender_name"],
      creator_id: user.id
    }

    with {:ok, message} <- Landgrab.create_organiser_message(attrs) do
      if params["send"] == true do
        {:ok, sent, team_count} = Landgrab.send_organiser_message(message)
        conn |> put_status(:created) |> json(sent |> render_message() |> Map.put(:team_count, team_count))
      else
        conn |> put_status(:created) |> json(render_message(message))
      end
    else
      {:error, changeset} -> render_changeset_error(conn, changeset)
    end
  end

  def send_message(conn, %{"id" => id}) do
    case Landgrab.get_organiser_message(id) do
      nil ->
        not_found(conn)

      message ->
        case Landgrab.send_organiser_message(message) do
          {:ok, sent, team_count} ->
            json(conn, sent |> render_message() |> Map.put(:team_count, team_count))

          {:error, :already_sent} ->
            conn
            |> put_status(:conflict)
            |> json(%{error: %{code: "already_sent", detail: "This message has already been sent."}})
        end
    end
  end

  defp render_message(message) do
    %{
      id: message.id,
      body: message.body,
      sender_name: message.sender_name,
      sent_at: message.sent_at,
      inserted_at: message.inserted_at
    }
  end

  defp not_found(conn) do
    conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})
  end

  defp render_changeset_error(conn, changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)})
  end
end
