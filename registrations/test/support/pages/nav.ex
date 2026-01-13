defmodule Registrations.Pages.Nav do
  @moduledoc false
  alias Wallaby.Browser
  alias Wallaby.Query

  def present?(session) do
    Browser.has?(session, Query.css(".row.nav"))
  end

  def info_text(session) do
    Browser.text(session, Query.css(".alert-info"))
  end

  def error_text(session) do
    Browser.text(session, Query.css(".alert-danger"))
  end

  def register_link do
    Registrations.Pages.Nav.RegisterLink
  end

  def login_link do
    Registrations.Pages.Nav.LoginLink
  end

  # FIXME there is surely a better way to do this?
  # macros/DSL to create page objects?
  def logout_link do
    Registrations.Pages.Nav.LogoutLink
  end

  def users_link do
    Registrations.Pages.Nav.UsersLink
  end

  def teams_link do
    Registrations.Pages.Nav.TeamsLink
  end

  def settings_link do
    Registrations.Pages.Nav.SettingsLink
  end

  def edit_details(session) do
    Browser.click(session, Query.css("a.details"))
  end

  def edit_messages(session) do
    Browser.click(session, Query.css("a.messages"))
  end

  defmodule LogoutLink do
    @moduledoc false
    alias Wallaby.Browser
    alias Wallaby.Query

    @selector "a.logout"

    def text(session) do
      Browser.text(session, Query.css(@selector))
    end

    def click(session) do
      Browser.click(session, Query.css(@selector))
    end
  end

  defmodule LoginLink do
    @moduledoc false
    alias Wallaby.Browser
    alias Wallaby.Query

    @selector "a.login"

    def click(session) do
      Browser.click(session, Query.css(@selector))
    end

    def present?(session) do
      Browser.has?(session, Query.css(@selector))
    end
  end

  defmodule RegisterLink do
    @moduledoc false
    alias Wallaby.Browser
    alias Wallaby.Query

    @selector "a.register"

    def click(session) do
      Browser.click(session, Query.css(@selector))
    end

    def present?(session) do
      Browser.has?(session, Query.css(@selector))
    end
  end

  defmodule UsersLink do
    @moduledoc false
    alias Wallaby.Browser
    alias Wallaby.Query

    @selector "a.users"

    def click(session) do
      Browser.click(session, Query.css(@selector))
    end

    def absent?(session) do
      not Browser.has?(session, Query.css(@selector))
    end
  end

  defmodule TeamsLink do
    @moduledoc false
    alias Wallaby.Browser
    alias Wallaby.Query

    @selector "a.teams"

    def click(session) do
      Browser.click(session, Query.css(@selector))
    end
  end

  defmodule SettingsLink do
    @moduledoc false
    alias Wallaby.Browser
    alias Wallaby.Query

    @selector "a.settings"

    def click(session) do
      Browser.click(session, Query.css(@selector))
    end
  end
end
