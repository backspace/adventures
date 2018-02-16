defmodule Cr2016site.UserController do
  use Cr2016site.Web, :controller

  alias Cr2016site.User

  require Logger

  plug Cr2016site.Plugs.Admin when action in [:index]
  plug Cr2016site.Plugs.LoginRequired when action in [:edit, :update]

  def index(conn, _params) do
    teams = Repo.all(Cr2016site.Team)

    users = Repo.all(User)
    |> Enum.map(fn(u) -> Map.put(u, :teamed, Enum.any?(teams, fn(t) -> Enum.member?(t.user_ids, u.id) end)) end)

    render conn, "index.html", users: users
  end

  def edit(conn, _) do
    users = Repo.all(User)
    current_user = conn.assigns[:current_user_object]
    changeset = User.details_changeset(current_user)

    conn = case Application.get_env(:cr2016site, :registration_closed) do
      true ->
        conn
        |> put_flash(:error, "You may change your details but it’s too late to guarantee the changes can be integrated")
      _ ->
        conn
    end

    render conn, "edit.html", user: current_user, relationships: Cr2016site.TeamFinder.relationships(current_user, users), changeset: changeset
  end

  def update(conn, %{"user" => user_params}) do
    users = Repo.all(User)
    current_user = conn.assigns[:current_user_object]
    changeset = User.details_changeset(current_user, user_params)

    case Repo.update(changeset) do
      {:ok, user} ->
        Cr2016site.Mailer.send_user_changes(current_user, changeset.changes)

        conn = case {changeset.changes[:txt_confirmation_sent], changeset.changes[:txt_confirmation_received]} do
          {nil, nil} -> put_flash(conn, :info, "Your details were saved")
        {nil, _} -> put_flash(conn, :info, "Thanks for confirming the txt")
          _ ->
            send_confirmation_txt(user)
            put_flash(conn, :info, "Your details were saved; please look for a txt")
        end

        conn
        |> redirect(to: user_path(conn, :edit))
      {:error, changeset} ->
        render(conn, "edit.html", user: current_user, relationships: Cr2016site.TeamFinder.relationships(current_user, users), changeset: changeset)
    end
  end

  def confirm(conn, %{"id" => id}) do
    user = Repo.get!(User, id)
    conn = fetch_query_params(conn)

    changeset = User.confirmation_changeset(user, %{txt_confirmation_received: conn.query_params["confirmation"]})

    case Repo.update(changeset) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Thanks for confirming the txt")
        |> redirect(to: user_path(conn, :edit))
      {:error, _} ->
        conn
        |> put_flash(:error, "That confirmation didn’t match!")
        |> redirect(to: user_path(conn, :edit))
    end
  end

  def resend(conn, %{"id" => id}) do
    user = Repo.get!(User, id)

    send_confirmation_txt(user)

    conn
    |> put_flash(:info, "We sent the confirmation code again")
    |> redirect(to: user_path(conn, :edit))
  end

  defp send_confirmation_txt(user) do
    Cr2016site.Txter.send_confirmation_txt(user)
  end
end
