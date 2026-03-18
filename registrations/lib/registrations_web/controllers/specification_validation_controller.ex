defmodule RegistrationsWeb.SpecificationValidationController do
  use RegistrationsWeb, :controller

  alias Registrations.Accounts
  alias Registrations.Waydowntown

  action_fallback(RegistrationsWeb.FallbackController)

  def create(conn, params) do
    current_user = Pow.Plug.current_user(conn)

    unless Accounts.has_role?(current_user, "validation_supervisor") do
      conn
      |> put_status(:forbidden)
      |> json(%{errors: [%{detail: "Must be a validation supervisor"}]})
    else
      validator_id = params["validator_id"]

      unless validator_id && Accounts.has_role?(%{id: validator_id}, "validator") do
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{detail: "Target user must have the validator role"}]})
      else
        attrs =
          params
          |> Map.put("assigned_by_id", current_user.id)

        case Waydowntown.create_specification_validation(attrs) do
          {:ok, validation} ->
            conn
            |> put_status(:created)
            |> render("show.json", %{data: validation, conn: conn, params: params})

          {:error, changeset} ->
            {:error, changeset}
        end
      end
    end
  end

  def index(conn, %{"specification_id" => specification_id} = params) do
    validations = Waydowntown.list_validations_for_specification(specification_id)
    render(conn, "index.json", %{data: validations, conn: conn, params: params})
  end

  def index(conn, params) do
    validations = Waydowntown.list_specification_validations()
    render(conn, "index.json", %{data: validations, conn: conn, params: params})
  end

  def mine(conn, params) do
    current_user = Pow.Plug.current_user(conn)
    validations = Waydowntown.list_validations_for_validator(current_user)
    render(conn, "index.json", %{data: validations, conn: conn, params: params})
  end

  def supervise(conn, params) do
    current_user = Pow.Plug.current_user(conn)
    validations = Waydowntown.list_validations_for_supervisor(current_user)
    render(conn, "index.json", %{data: validations, conn: conn, params: params})
  end

  def show(conn, %{"id" => id} = params) do
    current_user = Pow.Plug.current_user(conn)
    validation = Waydowntown.get_specification_validation!(id)

    if validation.validator_id == current_user.id or validation.assigned_by_id == current_user.id or
         current_user.admin do
      render(conn, "show.json", %{data: validation, conn: conn, params: params})
    else
      conn
      |> put_status(:forbidden)
      |> json(%{errors: [%{detail: "Not authorized to view this validation"}]})
    end
  end

  def update(conn, %{"id" => id} = params) do
    current_user = Pow.Plug.current_user(conn)
    validation = Waydowntown.get_specification_validation!(id)

    cond do
      validation.validator_id == current_user.id ->
        case Waydowntown.update_specification_validation(validation, params, :validator) do
          {:ok, updated} ->
            render(conn, "show.json", %{data: updated, conn: conn, params: params})

          {:error, changeset} ->
            {:error, changeset}
        end

      validation.assigned_by_id == current_user.id ->
        case Waydowntown.update_specification_validation(validation, params, :supervisor) do
          {:ok, updated} ->
            render(conn, "show.json", %{data: updated, conn: conn, params: params})

          {:error, changeset} ->
            {:error, changeset}
        end

      true ->
        conn
        |> put_status(:forbidden)
        |> json(%{errors: [%{detail: "Not authorized to update this validation"}]})
    end
  end
end
