defmodule RegistrationsWeb.Poles.AttachmentController do
  use RegistrationsWeb, :controller

  alias Registrations.Poles

  @doc """
  Serve attachment bytes to any authenticated user. Sets long-lived caching
  headers because attachment IDs are content-addressed (a new upload produces
  a new ID); existing bytes never change.
  """
  def show(conn, %{"id" => id}) do
    case Poles.get_attachment(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})

      attachment ->
        conn
        |> put_resp_header("content-type", attachment.content_type)
        |> put_resp_header("cache-control", "private, max-age=31536000, immutable")
        |> put_resp_header("etag", inspect(attachment.id))
        |> send_resp(:ok, attachment.data)
    end
  end

  @doc """
  Serve a small JPEG thumbnail for thumbnail/grid views. Falls back to the
  full-size bytes if the attachment predates thumbnail generation and the
  backfill hasn't been run yet.
  """
  def show_thumb(conn, %{"id" => id}) do
    case Poles.get_attachment(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})

      %{thumbnail_data: thumb} = attachment when is_binary(thumb) ->
        conn
        |> put_resp_header("content-type", "image/jpeg")
        |> put_resp_header("cache-control", "private, max-age=31536000, immutable")
        |> put_resp_header("etag", inspect({attachment.id, :thumb}))
        |> send_resp(:ok, thumb)

      attachment ->
        # No thumbnail yet — fall back to full bytes so the UI still works.
        conn
        |> put_resp_header("content-type", attachment.content_type)
        |> put_resp_header("cache-control", "private, max-age=300")
        |> send_resp(:ok, attachment.data)
    end
  end

  def create_for_pole(conn, %{"pole_id" => pole_id} = params) do
    user = Pow.Plug.current_user(conn)

    case fetch_upload(params) do
      {:ok, %{data: data, content_type: content_type, byte_size: byte_size}} ->
        attrs = %{
          pole_id: pole_id,
          data: data,
          content_type: content_type,
          byte_size: byte_size,
          creator_id: user.id
        }

        insert_and_render(conn, attrs)

      {:error, reason} ->
        bad_request(conn, reason)
    end
  end

  def create_for_puzzlet(conn, %{"puzzlet_id" => puzzlet_id} = params) do
    user = Pow.Plug.current_user(conn)

    case fetch_upload(params) do
      {:ok, %{data: data, content_type: content_type, byte_size: byte_size}} ->
        attrs = %{
          puzzlet_id: puzzlet_id,
          data: data,
          content_type: content_type,
          byte_size: byte_size,
          creator_id: user.id
        }

        insert_and_render(conn, attrs)

      {:error, reason} ->
        bad_request(conn, reason)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Pow.Plug.current_user(conn)

    case Poles.get_attachment(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})

      %{creator_id: creator_id} = attachment when creator_id == user.id ->
        {:ok, _} = Poles.delete_attachment(attachment)
        send_resp(conn, :no_content, "")

      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: %{code: "forbidden", detail: "You can only delete your own attachments."}})
    end
  end

  defp fetch_upload(%{"photo" => %Plug.Upload{path: path, content_type: content_type}}) do
    case File.read(path) do
      {:ok, data} ->
        {:ok, %{data: data, content_type: content_type || "application/octet-stream", byte_size: byte_size(data)}}

      {:error, reason} ->
        {:error, "Could not read uploaded file: #{inspect(reason)}"}
    end
  end

  defp fetch_upload(_), do: {:error, "Expected multipart upload with field `photo`."}

  defp insert_and_render(conn, attrs) do
    case Poles.create_attachment(attrs) do
      {:ok, attachment} ->
        conn
        |> put_status(:created)
        |> json(%{id: attachment.id, content_type: attachment.content_type, byte_size: attachment.byte_size})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(RegistrationsWeb.ChangesetView)
        |> render("error.json", %{changeset: changeset})
    end
  end

  defp bad_request(conn, detail) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: %{code: "bad_request", detail: detail}})
  end
end
