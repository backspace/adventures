defmodule RegistrationsWeb.RunController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Run

  require Logger

  plug(JSONAPI.QueryParser,
    view: RegistrationsWeb.RunView,
    filter: ["specification.concept", "specification.id", "specification.placed", "specification.position", "started"]
  )

  action_fallback(RegistrationsWeb.FallbackController)

  def index(conn, params) do
    runs = Waydowntown.list_runs(conn.params["filter"] || %{})
    render(conn, "index.json", %{data: runs, conn: conn, params: params})
  end

  def create(conn, params) do
    Logger.info("Creating run with params: #{inspect(params)}")
    specification_filter = get_specification_filter(conn.params)

    case Waydowntown.create_run(conn.assigns[:current_user], params, specification_filter) do
      {:ok, %Run{} = run} ->
        run = Waydowntown.get_run!(run.id)

        conn
        |> put_status(:created)
        |> put_resp_header("location", Routes.run_path(conn, :show, run))
        |> render("show.json", %{data: run, conn: conn, params: params})

      {:error, message} when is_binary(message) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{detail: message}]})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(RegistrationsWeb.ChangesetView)
        |> render("error.json", %{changeset: changeset})
    end
  end

  defp get_specification_filter(params) do
    case params["filter"] do
      %{"specification.position" => position} when is_binary(position) ->
        case String.split(position, ",") do
          [lat, lon] ->
            {latitude, _} = Float.parse(lat)
            {longitude, _} = Float.parse(lon)
            %{"position" => {latitude, longitude}}

          _ ->
            nil
        end

      %{"specification.placed" => placed} when placed in ["true", "false"] ->
        %{"placed" => placed}

      %{"specification.id" => id} when is_binary(id) ->
        %{"specification_id" => id}

      %{"specification.concept" => concept} when is_binary(concept) ->
        %{"concept" => concept}

      _ ->
        nil
    end
  end

  def show(conn, params) do
    run = Waydowntown.get_run!(params["id"])
    render(conn, "show.json", %{data: run, conn: conn, params: params})
  end

  def start(conn, %{"id" => id}) do
    run = Waydowntown.get_run!(id)

    case Waydowntown.start_run(conn.assigns[:current_user], run) do
      {:ok, started_run} ->
        render(conn, "show.json", %{data: started_run, conn: conn, params: %{}})

      {:error, message} when is_binary(message) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{detail: message}]})

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", message: "Unable to start the run")
    end
  end

  defp filter_runs(runs, %{"started" => started}) when started in ["true", "false"] do
    Enum.filter(runs, fn run ->
      case started do
        "true" -> not is_nil(run.started_at)
        "false" -> is_nil(run.started_at)
      end
    end)
  end

  defp filter_runs(runs, _), do: runs
end
