defmodule Mix.Tasks.Landgrab.FetchRivers do
  @shortdoc "Fetch OSM river centrelines for the LANDGRAB hero map"

  @moduledoc """
  Fetches OSM river centrelines for the LANDGRAB placeholder hero map
  and writes them as SVG path data, normalised to an 800×500 viewBox.

  Re-run this when you want fresh OSM data or need to retune the
  bounding box. The output JSON is committed to the repo and read by
  `lib/registrations_web/templates/page/landgrab.html.heex` at render time
  so the placeholder is a static fetch with no runtime network call.

      mix landgrab.fetch_rivers

  ## Why centrelines, not polygons

  The Red River relation in OSM is a 200+ way multipolygon — large,
  awkward to flatten, and adds little visual punch over a thick stroke
  on the centreline. Centrelines with `stroke-width` give us a clean,
  stylised river shape that still reads as the real geometry of the
  Forks.
  """
  use Mix.Task

  # South, West, North, East. Lower-right (south-east) corner is pinned
  # to the user-specified anchor; the other two sides are derived to
  # give an 8:5 viewBox aspect at this latitude (~2.5 km tall × 4 km
  # wide). The Forks and Portage & Main both fall inside this frame.
  @south 49.88467792271509
  @east -97.12412599256774
  @lat_span 0.0225
  # 1° lat ≈ 111 km and 1° lon ≈ 71.5 km at 49.89°N. For an 8:5 frame
  # `lon_span = lat_span * (8/5) * (111/71.5)` ≈ `lat_span * 2.484`.
  @lon_span 0.0559
  @bbox {@south, @east - @lon_span, @south + @lat_span, @east}
  @viewbox_width 800
  @viewbox_height 500
  @output_path "priv/landgrab/rivers.json"

  @impl Mix.Task
  def run(_args) do
    {south, west, north, east} = @bbox

    query = """
    [out:json][timeout:25];
    (
      way["waterway"="river"](#{south},#{west},#{north},#{east});
    );
    out geom;
    """

    Mix.shell().info("Fetching from Overpass …")
    json = call_overpass(query)
    %{"elements" => elements} = Jason.decode!(json)

    rivers =
      elements
      |> Enum.filter(&match?(%{"type" => "way", "geometry" => _}, &1))
      |> Enum.map(&project_way/1)
      |> Enum.reject(&(&1["path"] == ""))

    payload = %{
      "bbox" => %{"south" => south, "west" => west, "north" => north, "east" => east},
      "viewBox" => %{"width" => @viewbox_width, "height" => @viewbox_height},
      "rivers" => rivers,
      "generated_at" => DateTime.to_iso8601(DateTime.utc_now())
    }

    File.mkdir_p!(Path.dirname(@output_path))
    File.write!(@output_path, Jason.encode!(payload, pretty: true) <> "\n")

    Mix.shell().info("Wrote #{length(rivers)} river segments to #{@output_path}")
  end

  defp project_way(%{"id" => id, "geometry" => geom} = way) do
    name = get_in(way, ["tags", "name"]) || "(unnamed)"
    path = geom |> Enum.map(&project_point/1) |> to_svg_path()
    %{"id" => id, "name" => name, "path" => path}
  end

  defp project_point(%{"lat" => lat, "lon" => lon}) do
    {south, west, north, east} = @bbox
    x = (lon - west) / (east - west) * @viewbox_width
    y = (north - lat) / (north - south) * @viewbox_height
    {Float.round(x, 2), Float.round(y, 2)}
  end

  defp to_svg_path([]), do: ""

  defp to_svg_path([{x0, y0} | rest]) do
    rest
    |> Enum.map(fn {x, y} -> "L #{x} #{y}" end)
    |> List.insert_at(0, "M #{x0} #{y0}")
    |> Enum.join(" ")
  end

  defp call_overpass(query) do
    # Overpass blocks the default curl UA — set a real one. We pass the
    # query through a temp file so the shell never has to escape it.
    tmp = Path.join(System.tmp_dir!(), "landgrab-overpass-#{System.unique_integer([:positive])}.txt")
    File.write!(tmp, "data=" <> URI.encode_www_form(query))

    {output, status} =
      System.cmd(
        "curl",
        [
          "-sS",
          "--max-time",
          "60",
          "-A",
          "landgrab-fetch/1.0",
          "--data-binary",
          "@" <> tmp,
          "https://overpass-api.de/api/interpreter"
        ],
        stderr_to_stdout: true
      )

    _ = File.rm(tmp)

    case status do
      0 -> output
      n -> Mix.raise("curl exited with status #{n}: #{output}")
    end
  end
end
