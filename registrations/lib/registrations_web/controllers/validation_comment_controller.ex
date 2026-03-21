defmodule RegistrationsWeb.ValidationCommentController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown

  action_fallback(RegistrationsWeb.FallbackController)

  def create(conn, params) do
    current_user = Pow.Plug.current_user(conn)
    validation = Waydowntown.get_specification_validation!(params["specification_validation_id"])

    if validation.validator_id == current_user.id do
      case Waydowntown.create_validation_comment(params) do
        {:ok, comment} ->
          conn
          |> put_status(:created)
          |> render("show.json", %{data: comment, conn: conn, params: params})

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{errors: [%{detail: "Not authorized to comment on this validation"}]})
    end
  end

  def update(conn, %{"id" => id} = params) do
    current_user = Pow.Plug.current_user(conn)
    comment = Waydowntown.get_validation_comment!(id)
    validation = Waydowntown.get_specification_validation!(comment.specification_validation_id)

    if validation.validator_id == current_user.id or
         validation.assigned_by_id == current_user.id or
         current_user.admin do
      case Waydowntown.update_validation_comment(comment, params) do
        {:ok, updated} ->
          render(conn, "show.json", %{data: updated, conn: conn, params: params})

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{errors: [%{detail: "Not authorized to update this comment"}]})
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = Pow.Plug.current_user(conn)
    comment = Waydowntown.get_validation_comment!(id)
    validation = Waydowntown.get_specification_validation!(comment.specification_validation_id)

    if validation.validator_id == current_user.id do
      Waydowntown.delete_validation_comment(comment)
      send_resp(conn, :no_content, "")
    else
      conn
      |> put_status(:forbidden)
      |> json(%{errors: [%{detail: "Not authorized to delete this comment"}]})
    end
  end
end
