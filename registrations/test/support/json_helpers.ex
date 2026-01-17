defmodule Registrations.TestJsonHelpers do
  @moduledoc false

  import Wallaby.Browser, only: [page_source: 1]
  require WaitForIt

  def decode_json_from_page(session) do
    WaitForIt.wait!(json_ready?(session), timeout: 10_000)

    session
    |> page_source()
    |> extract_json()
    |> String.trim()
    |> Jason.decode!()
  end

  defp json_ready?(session) do
    session
    |> page_source()
    |> extract_json()
    |> String.trim()
    |> json_prefix?()
  end

  defp json_prefix?(json) do
    String.starts_with?(json, "{") or String.starts_with?(json, "[")
  end

  defp extract_json(body) do
    case Floki.find(body, "pre") do
      [] -> body
      nodes -> Floki.text(nodes)
    end
  end
end
