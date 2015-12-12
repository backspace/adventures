defmodule Cr2016site.Pages.Messages do
  use Hound.Helpers

  def new_message do
    click {:css, ".new-message"}
  end

  def fill_subject(subject) do
    fill_field({:id, "message_subject"}, subject)
  end

  def fill_content(content) do
    fill_field {:id, "message_content"}, content
  end

  def check_ready do
    click {:id, "message_ready"}
  end

  def save do
    click {:css, "input.btn.submit"}
  end

  def send do
    click {:css, ".btn.send"}
  end
end
