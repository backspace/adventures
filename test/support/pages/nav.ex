defmodule Cr2016site.Pages.Nav do
  use Hound.Helpers

  def info_text do
    visible_text({:css, ".alert-info"})
  end

  def error_text do
    visible_text({:css, ".alert-danger"})
  end

  def register_link do
    Cr2016site.Pages.Nav.RegisterLink
  end

  def login_link do
    Cr2016site.Pages.Nav.LoginLink
  end

  # FIXME there is surely a better way to do this?
  # macros/DSL to create page objects?
  def logout_link do
    Cr2016site.Pages.Nav.LogoutLink
  end

  def users_link do
    Cr2016site.Pages.Nav.UsersLink
  end

  def edit_details do
    click {:css, "a.details"}
  end

  defmodule LogoutLink do
    @selector {:css, "a.logout"}

    def text do
      visible_text(@selector)
    end

    def click do
      click(@selector)
    end
  end

  defmodule LoginLink do
    @selector {:css, "a.login"}

    def click do
      click @selector
    end

    def present? do
      # Is this reasonable?
      apply(Hound.Helpers.Page, :find_element, Tuple.to_list(@selector))
    end
  end

  defmodule RegisterLink do
    @selector {:css, "a.register"}

    def click do
      click @selector
    end

    def present? do
      apply(Hound.Helpers.Page, :find_element, Tuple.to_list(@selector))
    end
  end

  defmodule UsersLink do
    @selector {:css, "a.users"}

    def click do
      click @selector
    end

    def absent? do
      !apply(Hound.Matchers, :element?, Tuple.to_list(@selector))
    end
  end
end
