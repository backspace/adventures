defmodule RegistrationsWeb.Landgrab do
  @moduledoc """
  Compile-time loader for the OSM-derived river path data used by the
  LANDGRAB placeholder hero. The JSON is produced by
  `mix landgrab.fetch_rivers` and committed to the repo, so this module
  embeds the bytes at compile time and recompiles when the file on
  disk changes.
  """

  @rivers_path Path.join([:code.priv_dir(:registrations), "landgrab", "rivers.json"])
  @external_resource @rivers_path

  @rivers (if File.exists?(@rivers_path) do
             Jason.decode!(File.read!(@rivers_path))
           else
             %{
               "rivers" => [],
               "viewBox" => %{"width" => 800, "height" => 500}
             }
           end)

  @doc "Decoded rivers payload — see priv/landgrab/rivers.json"
  def data, do: @rivers

  def rivers, do: @rivers["rivers"] || []

  def view_box do
    vb = @rivers["viewBox"] || %{"width" => 800, "height" => 500}
    {vb["width"], vb["height"]}
  end

  @doc """
  Stroke width (in viewBox units) for a given river name. The Red and
  Assiniboine are the dominant features so they get the heavier strokes;
  the Seine is a creek by comparison.
  """
  def stroke_width(name) when is_binary(name) do
    cond do
      String.contains?(name, "Red River") -> 46
      String.contains?(name, "Assiniboine") -> 36
      String.contains?(name, "Seine") -> 18
      true -> 26
    end
  end

  def stroke_width(_), do: 26

  @doc "Casing width = inner stroke + a few px so a dark outline shows."
  def casing_width(name), do: stroke_width(name) + 8
end
