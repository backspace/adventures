defmodule Registrations.TestJsonHelpers do
  @moduledoc false

  import Wallaby.Browser, only: [page_source: 1]

  def decode_json_from_page(session) do
    body = page_source(session)

    json =
      case Floki.find(body, "pre") do
        [] -> body
        nodes -> Floki.text(nodes)
      end

    json
    |> String.trim()
    |> Jason.decode!()
  end
end
