defmodule Registrations.Pages.Home do
  @moduledoc false
  use Hound.Helpers

  def placeholder_exists? do
    Hound.Matchers.element?(:css, "[data-test-placeholder]")
  end

  def fill_name(name) do
    fill_field({:id, "question_name"}, name)
  end

  def fill_email(email) do
    fill_field({:id, "question_email"}, email)
  end

  def fill_subject(subject) do
    fill_field({:id, "question_subject"}, subject)
  end

  def fill_question(question) do
    fill_field({:id, "question_question"}, question)
  end

  def fill_waitlist_email(email) do
    fill_field({:id, "waitlist_email"}, email)
  end

  def fill_waitlist_question(question) do
    fill_field({:id, "waitlist_question"}, question)
  end

  def submit_question do
    click({:class, "button"})
  end

  def submit_waitlist do
    click({:class, "button"})
  end

  def pi do
    Registrations.Pages.Home.Pi
  end

  defmodule Pi do
    @moduledoc false
    @selector {:id, "pi"}

    def present? do
      apply(Hound.Matchers, :element?, Tuple.to_list(@selector))
    end

    def click do
      click(@selector)
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
      @selector {:css, "[data-test-voicepass]"}

      def present? do
        apply(Hound.Matchers, :element?, Tuple.to_list(@selector))
      end

      def text do
        visible_text(@selector)
      end
    end

    def regenerate do
      Registrations.Pages.Home.Overlay.Regenerate
    end

    defmodule Regenerate do
      @moduledoc false
      @selector {:css, "[data-test-regenerate]"}

      def present? do
        apply(Hound.Matchers, :element?, Tuple.to_list(@selector))
      end

      def text do
        visible_text(@selector)
      end

      def click do
        click(@selector)
      end
    end
  end
end
