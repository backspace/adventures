defmodule Registrations.Pages.Messages do
  @moduledoc false
  alias Wallaby.Browser
  alias Wallaby.Query

  def new_message(session) do
    Browser.click(session, Query.css(".new-message"))
  end

  def fill_from_name(session, name) do
    Browser.fill_in(session, Query.css("#message_from_name"), with: name)
  end

  def fill_from_address(session, address) do
    Browser.fill_in(session, Query.css("#message_from_address"), with: address)
  end

  def fill_subject(session, subject) do
    Browser.fill_in(session, Query.css("#message_subject"), with: subject)
  end

  def fill_content(session, content) do
    Browser.fill_in(session, Query.css("#message_content"), with: content)
  end

  def fill_postmarked_at(session, date) do
    Browser.execute_script(
      session,
      "document.querySelector('#message_postmarked_at').value = arguments[0]",
      [date]
    )
  end

  def check_ready(session) do
    Browser.click(session, Query.css("#message_ready"))
  end

  def check_show_team(session) do
    Browser.click(session, Query.css("#message_show_team"))
  end

  def save(session) do
    Browser.click(session, Query.css("button.submit"))
  end

  def send(session) do
    accept_confirm(session, fn inner_session ->
      Browser.click(inner_session, Query.css(".button.send"))
    end)
  end

  def send_to_me(session) do
    Browser.click(session, Query.css(".button.send_to_me"))
  end

  defp accept_confirm(session, action) do
    if function_exported?(Browser, :accept_confirm, 2) do
      _ = apply(Browser, :accept_confirm, [session, action])
      session
    else
      _ = Browser.execute_script(session, "window.confirm = function(){return true;};")
      action.(session)
      session
    end
  end
end
