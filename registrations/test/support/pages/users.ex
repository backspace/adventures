defmodule Registrations.Pages.Users do
  @moduledoc false
  use Hound.Helpers

  defp user_container(id) do
    "tr[id='user-#{id}']"
  end

  def email(id) do
    visible_text({:css, "#{user_container(id)} .email"})
  end

  def accessibility(id) do
    visible_text({:css, "#{user_container(id)} .accessibility"})
  end

  def attending(id) do
    visible_text({:css, "#{user_container(id)} .attending"})
  end

  def proposed_team_name(id) do
    visible_text({:css, "#{user_container(id)} .proposed-team-name"})
  end

  def teamed(id) do
    visible_text({:css, "#{user_container(id)} .teamed"}) == "✓"
  end

  def build_team_from(id) do
    click({:css, "#{user_container(id)} a"})
  end

  def all_emails do
    :css |> Hound.Helpers.Page.find_all_elements("tr .email") |> Enum.map(&visible_text/1)
  end
end
