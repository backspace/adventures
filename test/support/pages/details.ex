defmodule Cr2016site.Pages.Details do
  use Hound.Helpers

  def edit_account do
    click({:css, "a.account"})
  end

  def delete_account do
    click({:css, "a.delete"})
  end

  def proposers do
    find_all_elements(:css, ".proposers tr")
    |> Enum.map(&(email_and_text_row(&1)))
  end

  def mutuals do
    find_all_elements(:css, ".mutuals tr")
    |> Enum.map(fn(row) ->
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
    find_all_elements(:css, ".proposals-by-mutuals tr")
    |> Enum.map(&(email_and_text_row(&1)))
  end

  def invalids do
    find_all_elements(:css, ".invalids tr")
    |> Enum.map(&(email_and_text_row(&1)))
  end

  def proposees do
    find_all_elements(:css, ".proposees tr")
    |> Enum.map(&(email_and_text_row(&1)))
  end

  def fill_team_emails(team_emails) do
    fill_field({:id, "user_team_emails"}, team_emails)
  end

  def fill_proposed_team_name(proposed_team_name) do
    fill_field({:id, "user_proposed_team_name"}, proposed_team_name)
  end

  def choose_risk_aversion(level_string) do
    level_integer = Cr2016site.UserView.risk_aversion_string_into_integer[level_string]
    click({:css, "input.level-#{level_integer}"})
  end

  def choose_txt(choice \\ true) do
    click({:css, "input.txt-#{if choice, do: "true", else: "false"}"})
  end

  def choose_data do
    click({:css, "input.data-true"})
  end

  def fill_number(number) do
    fill_field({:id, "user_number"}, number)
  end

  def confirmation do
    Cr2016site.Pages.Details.Confirmation
  end

  def svg do
    Cr2016site.Pages.Details.SVG
  end

  def confirmation_success do
    Cr2016site.Pages.Details.ConfirmationSuccess
  end

  def number_error_present? do
    element? :css, ".errors .number"
    element? :css, ".form-group.number.has-error"
  end

  def fill_display_size(size) do
    fill_field({:id, "user_display_size"}, size)
  end

  def fill_accessibility(accessibility) do
    fill_field({:id, "user_accessibility"}, accessibility)
  end

  def accessibility_text do
    attribute_value({:id, "user_accessibility"}, "value")
  end

  def comments do
    Cr2016site.Pages.Details.Comments
  end

  defmodule Comments do
    @selector {:id, "user_comments"}

    def fill(comments) do
      fill_field(@selector, comments)
    end

    def value do
      attribute_value(@selector, "value")
    end
  end

  def source do
    Cr2016site.Pages.Details.Source
  end

  # FIXME this is just begging for DRYing!
  defmodule Source do
    @selector {:id, "user_source"}

    def fill(source) do
      fill_field(@selector, source)
    end

    def value do
      attribute_value(@selector, "value")
    end
  end

  defmodule Confirmation do
    def present? do
      element? :css, ".form-group.confirmation"
    end

    def fill(confirmation) do
      fill_field({:css, ".form-group.confirmation input"}, confirmation)
    end

    def error? do
      element? :css, ".errors .txt_confirmation_received"
      element? :css, ".form-group.confirmation.has-error"
    end

    def resend do
      click({:css, "a.resend"})
    end
  end

  defmodule SVG do
    def present? do
      element? :css, ".form-group.svg"
    end

    def yes do
      click({:css, "input.svg-true"})
    end

    def no do
      click({:css, "input.svg-false"})
    end
  end

  defmodule ConfirmationSuccess do
    def present? do
      element? :css, ".confirmation-success"
    end
  end

  defmodule Attending do
    def present? do
      element? :css, ".form-group.attending"
    end

    def yes do
      click({:css, "input.attending-true"})
    end

    def no do
      click({:css, "input.attending-false"})
    end

    defmodule Error do
      def present? do
        element? :css, ".errors .attending"
        element? :css, ".form-group.attending.has-error"
      end
    end
  end

  def active? do
    # FIXME is there no current_url or the like?
    element? :id, "user_accessibility"
  end

  def submit do
    click({:class, "button"})
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
