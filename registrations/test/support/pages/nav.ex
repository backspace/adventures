defmodule Registrations.Pages.Nav do
  @moduledoc false
  use Hound.Helpers

  alias Hound.Helpers.Page

  def present? do
    Hound.Matchers.element?(:css, ".row.nav")
  end

  def info_text do
    visible_text({:css, ".alert-info"})
  end

  def error_text do
    visible_text({:css, ".alert-danger"})
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

  def edit_details do
    click({:css, "a.details"})
  end

  def edit_messages do
    click({:css, "a.messages"})
  end

  defmodule LogoutLink do
    @moduledoc false
    @selector {:css, "a.logout"}

    def text do
      visible_text(@selector)
    end

    def click do
      click(@selector)
    end
  end

  defmodule LoginLink do
    @moduledoc false
    @selector {:css, "a.login"}

    def click do
      click(@selector)
    end

    def present? do
      # Is this reasonable?
      apply(Page, :find_element, Tuple.to_list(@selector))
    end
  end

  defmodule RegisterLink do
    @moduledoc false
    @selector {:css, "a.register"}

    def click do
      click(@selector)
    end

    def present? do
      apply(Page, :find_element, Tuple.to_list(@selector))
    end
  end

  defmodule UsersLink do
    @moduledoc false
    @selector {:css, "a.users"}

    def click do
      click(@selector)
    end

    def absent? do
      !apply(Hound.Matchers, :element?, Tuple.to_list(@selector))
    end
  end

  defmodule TeamsLink do
    @moduledoc false
    @selector {:css, "a.teams"}

    def click do
      click(@selector)
    end
  end

  defmodule SettingsLink do
    @moduledoc false
    @selector {:css, "a.settings"}

    def click do
      click(@selector)
    end
  end
end
