defmodule Registrations.Pages.Details do
  @moduledoc false
  alias Wallaby.Browser
  alias Wallaby.Element
  alias Wallaby.Query

  def edit_account(session) do
    Browser.click(session, Query.css("a.account"))
  end

  def delete_account(session) do
    accept_confirm(session, fn ->
      Browser.click(session, Query.css("a.delete"))
    end)
  end

  def proposers(session) do
    session
    |> Browser.all(Query.css("[data-test-proposers]"))
    |> Enum.map(&email_and_text_row(&1))
  end

  def mutuals(session) do
    session
    |> Browser.all(Query.css("[data-test-mutuals]"))
    |> Enum.map(fn row ->
      proposed_team_name_element = Browser.find(row, Query.css(".proposed-team-name"))
      risk_aversion_element = Browser.find(row, Query.css(".risk-aversion"))

      %{
        email: Element.text(Browser.find(row, Query.css(".email"))),
        symbol: Element.text(Browser.find(row, Query.css(".symbol"))),
        proposed_team_name: %{
          value: Element.text(proposed_team_name_element),
          conflict?: has_class?(proposed_team_name_element, "conflict"),
          agreement?: has_class?(proposed_team_name_element, "agreement")
        },
        risk_aversion: %{
          value: Element.text(risk_aversion_element),
          conflict?: has_class?(risk_aversion_element, "conflict"),
          agreement?: has_class?(risk_aversion_element, "agreement")
        }
      }
    end)
  end

  def proposals_by_mutuals(session) do
    session
    |> Browser.all(Query.css("[data-test-proposals-by-mutuals]"))
    |> Enum.map(&email_and_text_row(&1))
  end

  def invalids(session) do
    session
    |> Browser.all(Query.css("[data-test-invalids]"))
    |> Enum.map(&email_and_text_row(&1))
  end

  def proposees(session) do
    session
    |> Browser.all(Query.css("[data-test-proposees]"))
    |> Enum.map(&email_and_text_row(&1))
  end

  def fill_team_emails(session, team_emails) do
    Browser.fill_in(session, Query.css("#user_team_emails"), with: team_emails)
  end

  def fill_proposed_team_name(session, proposed_team_name) do
    Browser.fill_in(session, Query.css("#user_proposed_team_name"), with: proposed_team_name)
  end

  def choose_risk_aversion(session, level_string) do
    level_integer =
      RegistrationsWeb.UserView.risk_aversion_string_into_integer()[level_string]

    Browser.click(session, Query.css("input.level-#{level_integer}"))
  end

  def fill_accessibility(session, accessibility) do
    Browser.fill_in(session, Query.css("#user_accessibility"), with: accessibility)
  end

  def accessibility_text(session) do
    session
    |> Browser.find(Query.css("#user_accessibility"))
    |> Element.attr("value")
  end

  def team_emails(session) do
    session
    |> Browser.find(Query.css("[name='user[team_emails]']"))
    |> Element.attr("value")
  end

  def add_to_team_emails(session) do
    Browser.click(session, Query.css("[data-action=add-email]"))
  end

  def comments do
    Registrations.Pages.Details.Comments
  end

  defmodule Comments do
    @moduledoc false
    alias Wallaby.Browser
    alias Wallaby.Element
    alias Wallaby.Query

    @selector "#user_comments"

    def fill(session, comments) do
      Browser.fill_in(session, Query.css(@selector), with: comments)
    end

    def value(session) do
      session
      |> Browser.find(Query.css(@selector))
      |> Element.attr("value")
    end
  end

  def source do
    Registrations.Pages.Details.Source
  end

  # FIXME this is just begging for DRYing!
  defmodule Source do
    @moduledoc false
    alias Wallaby.Browser
    alias Wallaby.Element
    alias Wallaby.Query

    @selector "#user_source"

    def fill(session, source) do
      Browser.fill_in(session, Query.css(@selector), with: source)
    end

    def value(session) do
      session
      |> Browser.find(Query.css(@selector))
      |> Element.attr("value")
    end
  end

  defmodule InviteButton do
    @moduledoc false
    alias Wallaby.Browser
    alias Wallaby.Query

    def present?(session) do
      Browser.has?(session, Query.css("[data-test-invite]"))
    end

    def click(session) do
      Browser.click(session, Query.css("[data-test-invite]"))
    end
  end

  defmodule Attending do
    @moduledoc false
    alias Wallaby.Browser
    alias Wallaby.Query

    def present?(session) do
      Browser.has?(session, Query.css(".form-group.attending"))
    end

    def yes(session) do
      Browser.click(session, Query.css("input.attending-true"))
    end

    def no(session) do
      Browser.click(session, Query.css("input.attending-false"))
    end

    defmodule Error do
      @moduledoc false
      alias Wallaby.Browser
      alias Wallaby.Query

      def present?(session) do
        Browser.has?(session, Query.css(".errors .attending"))
      end
    end
  end

  defmodule Team do
    @moduledoc false
    alias Wallaby.Browser
    alias Wallaby.Query

    def present?(session) do
      Browser.has?(session, Query.css("[data-test-assigned-team]"))
    end

    def name(session) do
      Browser.text(session, Query.css("[data-test-assigned-team-name]"))
    end

    def risk_aversion(session) do
      Browser.text(session, Query.css("[data-test-assigned-team-risk-aversion]"))
    end

    def emails(session) do
      Browser.text(session, Query.css("[data-test-assigned-team-emails]"))
    end
  end

  def active?(session) do
    Browser.current_path(session) == "/details"
  end

  def submit(session) do
    Browser.click(session, Query.css("#submit"))
  end

  defp email_and_text_row(row) do
    %{
      email: Element.text(Browser.find(row, Query.css(".email"))),
      symbol: Element.text(Browser.find(row, Query.css(".symbol"))),
      text: Element.text(Browser.find(row, Query.css(".text"))),
      add: fn -> Browser.click(Browser.find(row, Query.css("a"))) end
    }
  end

  defp has_class?(element, class_name) do
    element
    |> Element.attr("class")
    |> to_string()
    |> String.split()
    |> Enum.member?(class_name)
  end

  defp accept_confirm(session, action) do
    if function_exported?(Browser, :accept_confirm, 2) do
      _ = apply(Browser, :accept_confirm, [session, action])
      session
    else
      _ = Browser.execute_script(session, "window.confirm = function(){return true;};")
      action.()
      session
    end
  end
end
