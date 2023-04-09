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

  def pi_present? do
    element?(:id, "pi")
  end
end
