defmodule Registrations.Pages.Home do
  @moduledoc false
  alias Wallaby.Browser
  alias Wallaby.Query

  def placeholder_exists?(session) do
    Browser.has?(session, Query.css("[data-test-placeholder]"))
  end

  def fill_name(session, name) do
    Browser.fill_in(session, Query.css("#question_name"), with: name)
  end

  def fill_email(session, email) do
    Browser.fill_in(session, Query.css("#question_email"), with: email)
  end

  def fill_subject(session, subject) do
    Browser.fill_in(session, Query.css("#question_subject"), with: subject)
  end

  def fill_question(session, question) do
    Browser.fill_in(session, Query.css("#question_question"), with: question)
  end

  def fill_waitlist_email(session, email) do
    Browser.fill_in(session, Query.css("#waitlist_email"), with: email)
  end

  def fill_waitlist_question(session, question) do
    Browser.fill_in(session, Query.css("#waitlist_question"), with: question)
  end

  def submit_question(session) do
    Browser.click(session, Query.css(".button"))
  end

  def submit_waitlist(session) do
    Browser.click(session, Query.css(".button"))
  end

  def pi do
    Registrations.Pages.Home.Pi
  end

  defmodule Pi do
    @moduledoc false
    alias Wallaby.Browser
    alias Wallaby.Query
    require WaitForIt

    @selector "#pi"

    def present?(session) do
      Browser.has?(session, Query.css(@selector))
    end

    def click(session) do
      WaitForIt.wait!(
        try do
          Browser.click(session, Query.css(@selector))
          true
        rescue
          Wallaby.StaleReferenceError -> false
          Wallaby.QueryError -> false
          RuntimeError -> false
        end
      )
    end
  end

  def overlay do
    Registrations.Pages.Home.Overlay
  end

  defmodule Overlay do
    @moduledoc false
    def voicepass do
      Registrations.Pages.Home.Overlay.Voicepass
    end

    defmodule Voicepass do
      @moduledoc false
      alias Wallaby.Browser
      alias Wallaby.Query

      @selector "[data-test-voicepass]"

      def present?(session) do
        Browser.has?(session, Query.css(@selector))
      end

      def text(session) do
        Browser.text(session, Query.css(@selector))
      end
    end

    def regenerate do
      Registrations.Pages.Home.Overlay.Regenerate
    end

    defmodule Regenerate do
      @moduledoc false
      alias Wallaby.Browser
      alias Wallaby.Query

      @selector "[data-test-regenerate]"

      def present?(session) do
        Browser.has?(session, Query.css(@selector))
      end

      def text(session) do
        Browser.text(session, Query.css(@selector))
      end

      def click(session) do
        Browser.click(session, Query.css(@selector))
      end
    end
  end
end
