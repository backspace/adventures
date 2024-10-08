defmodule Registrations.Pages.Details do
  @moduledoc false
  use Hound.Helpers

  def edit_account do
    click({:css, "a.account"})
  end

  def delete_account do
    click({:css, "a.delete"})
    accept_dialog()
  end

  def proposers do
    :css
    |> find_all_elements("[data-test-proposers]")
    |> Enum.map(&email_and_text_row(&1))
  end

  def mutuals do
    :css
    |> find_all_elements("[data-test-mutuals]")
    |> Enum.map(fn row ->
      proposed_team_name_element = find_within_element(row, :css, ".proposed-team-name")
      risk_aversion_element = find_within_element(row, :css, ".risk-aversion")

      %{
        email: visible_text(find_within_element(row, :css, ".email")),
        symbol: visible_text(find_within_element(row, :css, ".symbol")),
        proposed_team_name: %{
          value: visible_text(proposed_team_name_element),
          conflict?: has_class?(proposed_team_name_element, "conflict"),
          agreement?: has_class?(proposed_team_name_element, "agreement")
        },
        risk_aversion: %{
          value: visible_text(risk_aversion_element),
          conflict?: has_class?(risk_aversion_element, "conflict"),
          agreement?: has_class?(risk_aversion_element, "agreement")
        }
      }
    end)
  end

  def proposals_by_mutuals do
    :css
    |> find_all_elements("[data-test-proposals-by-mutuals]")
    |> Enum.map(&email_and_text_row(&1))
  end

  def invalids do
    :css
    |> find_all_elements("[data-test-invalids]")
    |> Enum.map(&email_and_text_row(&1))
  end

  def proposees do
    :css
    |> find_all_elements("[data-test-proposees]")
    |> Enum.map(&email_and_text_row(&1))
  end

  def fill_team_emails(team_emails) do
    fill_field({:id, "user_team_emails"}, team_emails)
  end

  def fill_proposed_team_name(proposed_team_name) do
    fill_field({:id, "user_proposed_team_name"}, proposed_team_name)
  end

  def choose_risk_aversion(level_string) do
    level_integer =
      RegistrationsWeb.UserView.risk_aversion_string_into_integer()[level_string]

    click({:css, "input.level-#{level_integer}"})
  end

  def fill_accessibility(accessibility) do
    fill_field({:id, "user_accessibility"}, accessibility)
  end

  def accessibility_text do
    attribute_value({:id, "user_accessibility"}, "value")
  end

  def team_emails do
    attribute_value({:name, "user[team_emails]"}, "value")
  end

  def add_to_team_emails do
    click({:css, "[data-action=add-email]"})
  end

  def comments do
    Registrations.Pages.Details.Comments
  end

  defmodule Comments do
    @moduledoc false
    @selector {:id, "user_comments"}

    def fill(comments) do
      fill_field(@selector, comments)
    end

    def value do
      attribute_value(@selector, "value")
    end
  end

  def source do
    Registrations.Pages.Details.Source
  end

  # FIXME this is just begging for DRYing!
  defmodule Source do
    @moduledoc false
    @selector {:id, "user_source"}

    def fill(source) do
      fill_field(@selector, source)
    end

    def value do
      attribute_value(@selector, "value")
    end
  end

  defmodule InviteButton do
    @moduledoc false
    def present? do
      element?(:css, "[data-test-invite]")
    end

    def click do
      click({:css, "[data-test-invite]"})
    end
  end

  defmodule Attending do
    @moduledoc false
    def present? do
      element?(:css, ".form-group.attending")
    end

    def yes do
      click({:css, "input.attending-true"})
    end

    def no do
      click({:css, "input.attending-false"})
    end

    defmodule Error do
      @moduledoc false
      def present? do
        element?(:css, ".errors .attending")
      end
    end
  end

  defmodule Team do
    @moduledoc false
    def present? do
      element?(:css, "[data-test-assigned-team]")
    end

    def name do
      visible_text({:css, "[data-test-assigned-team-name]"})
    end

    def risk_aversion do
      visible_text({:css, "[data-test-assigned-team-risk-aversion]"})
    end

    def emails do
      visible_text({:css, "[data-test-assigned-team-emails]"})
    end
  end

  def active? do
    current_path() == "/details"
  end

  def submit do
    click({:id, "submit"})
  end

  defp email_and_text_row(row) do
    %{
      email: visible_text(find_within_element(row, :css, ".email")),
      symbol: visible_text(find_within_element(row, :css, ".symbol")),
      text: visible_text(find_within_element(row, :css, ".text")),
      add: fn -> click(find_within_element(row, :css, "a")) end
    }
  end
end
