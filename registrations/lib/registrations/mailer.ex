defmodule Registrations.Mailer do
  use Pow.Phoenix.Mailer
  use Swoosh.Mailer, otp_app: :registrations

  import Swoosh.Email
  import RegistrationsWeb.SharedHelpers
  import Ecto.Query, only: [from: 2]

  require Logger

  @from "b@events.chromatin.ca"

  @impl true
  def cast(%{user: user, subject: subject, text: text, html: html}) do
    %Swoosh.Email{}
    |> to({"", user.email})
    |> Swoosh.Email.from(adventure_from())
    |> subject("[#{phrase("email_title")}] #{subject}")
    |> html_body(html)
    |> text_body(text)
  end

  @impl true
  def process(email) do
    # An asynchronous process should be used here to prevent enumeration
    # attacks. Synchronous e-mail delivery can reveal whether a user already
    # exists in the system or not.

    Task.start(fn ->
      email
      |> deliver()
      |> log_warnings()
    end)

    :ok
  end

  def user_created(user) do
    messages =
      Registrations.Repo.all(
        Ecto.Query.from(m in RegistrationsWeb.Message,
          where: m.ready == true,
          select: m,
          order_by: :postmarked_at
        )
      )

    unless Enum.empty?(messages) do
      send_backlog(messages, user)
    end

    send_welcome_email(user.email)
    send_registration(user)
  end

  def send_welcome_email(email) do
    new()
    |> to(email)
    |> Swoosh.Email.from(adventure_from())
    |> subject("[#{phrase("email_title")}] Welcome!")
    |> html_body(welcome_html())
    |> text_body(welcome_text())
    |> deliver
  end

  def send_question(attributes) do
    new()
    |> to(adventure_from())
    |> Swoosh.Email.from(adventure_from())
    |> subject(
      "Question from #{attributes["name"]} <#{attributes["email"]}>: #{attributes["subject"]}"
    )
    |> text_body(attributes["question"])
    |> deliver
  end

  def waitlist_email(email, question) do
    new()
    |> to(email)
    |> Swoosh.Email.from("mdrysdale@chromatin.ca")
    |> subject("Waitlist submission from #{email}")
    |> text_body("Email: #{email}\nQuestion: #{question}")
    |> deliver
  end

  def send_user_changes(user, changes) do
    new()
    |> to(adventure_from())
    |> Swoosh.Email.from(adventure_from())
    |> subject("#{user.email} details changed: #{Enum.join(Enum.sort(Map.keys(changes)), ", ")}")
    |> text_body(inspect(Enum.sort_by(changes, fn {k, _v} -> k end)))
    |> deliver
  end

  def send_user_deletion(user) do
    new()
    |> to(adventure_from())
    |> Swoosh.Email.from(adventure_from())
    |> subject("#{user.email} deleted their account")
    |> text_body(inspect(user))
    |> deliver
  end

  @spec send_registration(atom() | %{:email => any(), optional(any()) => any()}) ::
          {:error, any()} | {:ok, any()}
  def send_registration(user) do
    new()
    |> to(adventure_from())
    |> Swoosh.Email.from(adventure_from())
    |> subject("#{user.email} registered")
    |> text_body("Yes")
    |> deliver
  end

  def send_message(message, user, relationships, team) do
    new()
    |> to(user.email)
    |> Swoosh.Email.from(message_from(message.from_name, message.from_address))
    |> subject("[#{phrase("email_title")}] #{message.subject}")
    |> text_body(message_text(message, user, relationships, team))
    |> html_body(message_html(message, user, relationships, team))
    |> deliver
  end

  def send_backlog(messages, user) do
    subject =
      case length(messages) do
        1 -> "Message sent before you registered"
        _ -> "Messages sent before you registered"
      end

    new()
    |> to(user.email)
    |> Swoosh.Email.from(adventure_from())
    |> subject("[#{phrase("email_title")}] #{subject}")
    |> text_body(backlog_text(messages))
    |> html_body(backlog_html(messages))
    |> deliver
  end

  defp welcome_html do
    Phoenix.View.render_to_string(
      RegistrationsWeb.EmailView,
      "#{adventure()}-welcome.html",
      %{
        layout: email_layout()
      }
    )
    |> Premailex.to_inline_css()
  end

  defp welcome_text do
    Premailex.to_text(welcome_html())
  end

  defp message_html(message, user, relationships, team) do
    Phoenix.View.render_to_string(RegistrationsWeb.MessageView, "preview.html", %{
      message: message,
      user: user,
      relationships: relationships,
      team: team,
      layout: email_layout()
    })
    |> Premailex.to_inline_css()
  end

  defp message_text(message, user, relationships, team) do
    Premailex.to_text(message_html(message, user, relationships, team))
  end

  defp backlog_html(messages) do
    Phoenix.View.render_to_string(RegistrationsWeb.MessageView, "backlog.html", %{
      messages: messages,
      layout: email_layout()
    })
    |> Premailex.to_inline_css()
  end

  defp backlog_text(messages) do
    Premailex.to_text(backlog_html(messages))
  end

  defp email_layout do
    {RegistrationsWeb.EmailView, "#{adventure()}-layout.html"}
  end

  defp message_from(from_name, from_address) do
    case from_address do
      "" -> @from
      nil -> @from
      _ -> {from_name, from_address}
    end
  end

  defp adventure_from() do
    if RegistrationsWeb.SharedHelpers.is_unmnemonic_devices() do
      "knut@chromatin.ca"
    else
      @from
    end
  end

  def message_from_string(message) do
    case message.from_address do
      "" -> nil
      nil -> nil
      _ -> "From: #{message.from_name} <#{message.from_address}>"
    end
  end

  defp log_warnings({:error, reason}) do
    Logger.warning("Mailer backend failed with: #{inspect(reason)}")
  end

  defp log_warnings({:ok, response}), do: {:ok, response}
end
