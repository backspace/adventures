defmodule Registrations.Pages.Teams do
  use Hound.Helpers

  defp team_container(index) do
    "tbody tr:nth-child(#{index})"
  end

  def name(index) do
    visible_text({:css, "#{team_container(index)} .name"})
  end

  def risk_aversion(index) do
    visible_text({:css, "#{team_container(index)} .risk-aversion"})
  end

  def emails(index) do
    visible_text({:css, "#{team_container(index)} [data-test-emails]"})
  end
end
