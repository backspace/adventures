defmodule Mix.Tasks.Landgrab.Licenses do
  @shortdoc "Generate the server dependency license inventory (JSON) for the app"

  @moduledoc """
  Generates a JSON inventory of the server's Hex dependencies and their SPDX
  licenses, for the Flutter app's "Server open-source licenses" page.

  Reads each `deps/<pkg>/hex_metadata.config` for the package name, version,
  and declared license id(s). Hex tarballs don't ship the license *text*, so
  only the SPDX identifiers are captured; the app pairs them with the
  canonical text for each license.

  Re-run whenever `mix.lock` changes:

      mix landgrab.licenses
      mix landgrab.licenses --output /some/other/path.json
  """
  use Mix.Task

  # Relative to the registrations app root (where mix runs).
  @default_output "../landgrab_app/assets/licenses/server_deps.json"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [output: :string])
    output = opts[:output] || @default_output

    deps =
      "deps/*/hex_metadata.config"
      |> Path.wildcard()
      |> Enum.map(&read_metadata/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(&String.downcase(&1.name))

    File.mkdir_p!(Path.dirname(output))
    File.write!(output, Jason.encode!(deps, pretty: true) <> "\n")

    Mix.shell().info("Wrote #{length(deps)} dependencies to #{output}")
  end

  defp read_metadata(path) do
    case :file.consult(path) do
      {:ok, terms} ->
        # hex_metadata.config is a flat list of {<<"key">>, value} terms;
        # binary keys compare equal to Elixir string literals.
        map = Map.new(terms)

        case map["name"] do
          nil ->
            nil

          name ->
            %{
              name: name,
              version: map["version"],
              licenses: map |> Map.get("licenses", []) |> normalize_licenses()
            }
        end

      _ ->
        nil
    end
  end

  defp normalize_licenses(list) do
    list
    |> Enum.map(&normalize/1)
    |> Enum.uniq()
  end

  # Fold the handful of non-canonical spellings onto their SPDX ids so the
  # app can key its license text off a stable set. "BSD" is left as-is
  # (ambiguous between 2- and 3-clause) — the app shows a generic fallback.
  defp normalize("Apache 2.0"), do: "Apache-2.0"
  defp normalize("BSD 2-Clause"), do: "BSD-2-Clause"
  defp normalize(id), do: id
end
