defmodule RegistrationsWeb.IncarnationController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Incarnation

  action_fallback RegistrationsWeb.FallbackController

  def index(conn, _params) do
    incarnations = Waydowntown.list_incarnations()
    render(conn, "index.json", incarnations: incarnations)
  end

  def create(conn, %{"incarnation" => incarnation_params}) do
    with {:ok, %Incarnation{} = incarnation} <- Waydowntown.create_incarnation(incarnation_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.incarnation_path(conn, :show, incarnation))
      |> render("show.json", incarnation: incarnation)
    end
  end

  def show(conn, %{"id" => id}) do
    incarnation = Waydowntown.get_incarnation!(id)
    render(conn, "show.json", incarnation: incarnation)
  end

  def update(conn, %{"id" => id, "incarnation" => incarnation_params}) do
    incarnation = Waydowntown.get_incarnation!(id)

    with {:ok, %Incarnation{} = incarnation} <- Waydowntown.update_incarnation(incarnation, incarnation_params) do
      render(conn, "show.json", incarnation: incarnation)
    end
  end

  def delete(conn, %{"id" => id}) do
    incarnation = Waydowntown.get_incarnation!(id)

    with {:ok, %Incarnation{}} <- Waydowntown.delete_incarnation(incarnation) do
      send_resp(conn, :no_content, "")
    end
  end
end
