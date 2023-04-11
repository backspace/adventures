defmodule AdventureRegistrations.Pages.Home do
  use Hound.Helpers

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

  def submit_question do
    click({:class, "button"})
  end

  def pi do
    AdventureRegistrations.Pages.Home.Pi
  end

  defmodule Pi do
    @selector {:id, "pi"}

    def present? do
      apply(Hound.Matchers, :element?, Tuple.to_list(@selector))
    end

    def click do
      click(@selector)
    end
  end

  def overlay do
    AdventureRegistrations.Pages.Home.Overlay
  end

  defmodule Overlay do
    def voicepass do
      AdventureRegistrations.Pages.Home.Overlay.Voicepass
    end

    defmodule Voicepass do
      @selector {:css, "[data-test-voicepass]"}

      def present? do
        apply(Hound.Matchers, :element?, Tuple.to_list(@selector))
      end

      def text do
        visible_text(@selector)
      end
    end

    def regenerate do
      AdventureRegistrations.Pages.Home.Overlay.Regenerate
    end

    defmodule Regenerate do
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
