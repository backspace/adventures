defmodule Registrations.Pages.Details do
  @moduledoc false
  alias Wallaby.Browser
  alias Wallaby.Element
  alias Wallaby.Query
  require WaitForIt

  def edit_account(session) do
    Browser.click(session, Query.css("a.account"))
  end

  def delete_account(session) do
    Browser.accept_confirm(session, fn inner_session ->
      Browser.click(inner_session, Query.css("a.delete"))
    end)
  end

  def proposers(session, opts \\ []) do
    map_rows_with_wait(session, "[data-test-proposers]", opts, &email_and_text_row/1)
  end

  def mutuals(session, opts \\ []) do
    map_rows_with_wait(session, "[data-test-mutuals]", opts, fn row ->
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

  def proposals_by_mutuals(session, opts \\ []) do
    map_rows_with_wait(
      session,
      "[data-test-proposals-by-mutuals]",
      opts,
      &email_and_text_row/1
    )
  end

  def invalids(session, opts \\ []) do
    map_rows_with_wait(session, "[data-test-invalids]", opts, &email_and_text_row/1)
  end

  def proposees(session, opts \\ []) do
    map_rows_with_wait(session, "[data-test-proposees]", opts, &email_and_text_row/1)
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
    require WaitForIt

    def present?(session) do
      Browser.has?(session, Query.css("[data-test-invite]"))
    end

    def click(session) do
      Browser.click(session, Query.css("[data-test-invite]"))
    end

    def assert_absent(session, message \\ nil) do
      WaitForIt.wait!(!present?(session))

      if present?(session) do
        raise(message || "Expected invite button to be absent")
      end
    end
  end

  defmodule Attending do
    @moduledoc false
    alias Wallaby.Browser
    alias Wallaby.Query
    require WaitForIt

    def present?(session) do
      Browser.has?(session, Query.css(".form-group.attending"))
    end

    def yes(session) do
      Browser.click(session, Query.css("input.attending-true"))
      WaitForIt.wait!(Browser.has?(session, Query.css("input.attending-true:checked")))
    end

    def no(session) do
      Browser.click(session, Query.css("input.attending-false"))
      WaitForIt.wait!(Browser.has?(session, Query.css("input.attending-false:checked")))
    end

    defmodule Error do
      @moduledoc false
      alias Wallaby.Browser
      alias Wallaby.Query
      require WaitForIt

      def present?(session) do
        Browser.has?(session, Query.css(".errors .attending"))
      end

      def assert_present(session, message \\ nil) do
        WaitForIt.wait!(safe_present?(session) == {:ok, true})

        if safe_present?(session) != {:ok, true} do
          raise(message || "Expected attending error to be present")
        end
      end

      def assert_absent(session, message \\ nil) do
        WaitForIt.wait!(safe_present?(session) == {:ok, false})

        if safe_present?(session) != {:ok, false} do
          raise(message || "Expected attending error to be absent")
        end
      end

      defp safe_present?(session) do
        try do
          {:ok, present?(session)}
        rescue
          Wallaby.StaleReferenceError -> :error
          Wallaby.QueryError -> :error
          error in RuntimeError -> handle_runtime_dom_error(error, __STACKTRACE__)
        end
      end

      defp handle_runtime_dom_error(%RuntimeError{message: message} = error, stacktrace) do
        if String.contains?(message, "does not belong to the document") do
          :error
        else
          reraise error, stacktrace
        end
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

  defp map_rows_with_wait(session, selector, opts, mapper) do
    expected = Keyword.get(opts, :count)

    WaitForIt.wait!(match?({:ok, _}, safe_map_rows(session, selector, expected, mapper)))

    case safe_map_rows(session, selector, expected, mapper) do
      {:ok, rows} -> rows
      :retry -> map_rows_with_wait(session, selector, opts, mapper)
    end
  end

  defp email_and_text_row(row) do
    %{
      email: Element.text(Browser.find(row, Query.css(".email"))),
      symbol: Element.text(Browser.find(row, Query.css(".symbol"))),
      text: Element.text(Browser.find(row, Query.css(".text"))),
      add: fn -> Element.click(Browser.find(row, Query.css("a"))) end
    }
  end

  defp has_class?(element, class_name) do
    element
    |> Element.attr("class")
    |> to_string()
    |> String.split()
    |> Enum.member?(class_name)
  end

  defp safe_map_rows(session, selector, expected, mapper) do
    try do
      rows = Browser.all(session, Query.css(selector))

      if expected && length(rows) != expected do
        :retry
      else
        {:ok, Enum.map(rows, mapper)}
      end
    rescue
      Wallaby.StaleReferenceError -> :retry
      Wallaby.QueryError -> :retry
      error in RuntimeError -> handle_runtime_dom_error(error, __STACKTRACE__)
    end
  end

  defp handle_runtime_dom_error(%RuntimeError{message: message} = error, stacktrace) do
    if String.contains?(message, "does not belong to the document") do
      :retry
    else
      reraise error, stacktrace
    end
  end

end
