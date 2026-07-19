defmodule RegistrationsWeb.AnswerKeyView do
  use RegistrationsWeb, :view

  @doc """
  Render a barcode value as an inline Code 128 SVG. Code 128 covers
  full ASCII, so it round-trips whatever string the pole's physical
  barcode carried regardless of the original symbology — the scanner
  compares decoded strings, not symbologies.
  """
  def barcode_svg(value, opts \\ []) do
    {:ok, svg} =
      value
      |> Barlix.Code128.encode!()
      |> Barlix.SVG.print(xdim: 2, height: Keyword.get(opts, :height, 60))

    # Strip the XML prolog — invalid when inlined into an HTML page.
    svg
    |> String.replace(~r/^<\?xml[^>]*\?>\n?/, "")
    |> raw()
  rescue
    # Code 128 only encodes ASCII; an unencodable value (e.g. a
    # barcode-type answer with unicode in it) renders as text alone
    # rather than failing the whole key.
    _ -> nil
  end

  @doc """
  A pole's synthetic display name (the stable Automatic Insurrection handle) —
  the only name a pole has now; the old author `label` is not shown anywhere.
  """
  def pole_name(pole), do: Registrations.Landgrab.pole_name(pole)

  @doc """
  The team's members as comma-separated email usernames (the part
  before the @), sorted — enough to recognise who's who without
  printing full addresses on the sheet.
  """
  def member_usernames(team) do
    team.users
    |> Enum.map(fn user -> user.email |> String.split("@") |> hd() end)
    |> Enum.sort()
    |> Enum.join(", ")
  end
end
