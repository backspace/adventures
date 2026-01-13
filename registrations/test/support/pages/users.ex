defmodule Registrations.Pages.Users do
  @moduledoc false
  alias Wallaby.Browser
  alias Wallaby.Element
  alias Wallaby.Query

  defp user_container(id) do
    "tr[id='user-#{id}']"
  end

  def email(session, id) do
    Browser.text(session, Query.css("#{user_container(id)} .email"))
  end

  def accessibility(session, id) do
    Browser.text(session, Query.css("#{user_container(id)} .accessibility"))
  end

  def attending(session, id) do
    Browser.text(session, Query.css("#{user_container(id)} .attending"))
  end

  def proposed_team_name(session, id) do
    Browser.text(session, Query.css("#{user_container(id)} .proposed-team-name"))
  end

  def teamed(session, id) do
    Browser.text(session, Query.css("#{user_container(id)} .teamed")) == "✓"
  end

  def build_team_from(session, id) do
    Browser.click(session, Query.css("#{user_container(id)} a"))
  end

  def all_emails(session) do
    session
    |> Browser.all(Query.css("tr .email"))
    |> Enum.map(&Element.text/1)
  end
end
