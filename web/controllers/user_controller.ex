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
        sid = Application.get_env(:cr2016site, :twilio_sid)
        token = Application.get_env(:cr2016site, :twilio_token)
        twilio_number = Application.get_env(:cr2016site, :twilio_number)

        Cr2016site.Mailer.send_user_changes(current_user, changeset.changes)

        conn = case {changeset.changes[:txt_confirmation_sent], changeset.changes[:txt_confirmation_received]} do
          {nil, nil} -> put_flash(conn, :info, "Your details were saved")
        {nil, _} -> put_flash(conn, :info, "Thanks for confirming the txt")
          _ ->
            HTTPoison.post(
              "https://#{sid}:#{token}@api.twilio.com/2010-04-01/Accounts/#{sid}/Messages",
              {:form, [
                {"From", twilio_number},
                {"To", "+1#{user.number}"},
                {"Body", "txtbeyond confirmation code: #{user.txt_confirmation_sent}\n\nConfirm at #{user_url(Cr2016site.Endpoint, :confirm, user.id, confirmation: user.txt_confirmation_sent)}"}
              ]})
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
end
