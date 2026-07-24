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
  Render a barcode-type *answer* as a scannable code. A URL-shaped answer
  is almost certainly a QR code out in the world (that's how you scan a
  URL), so draw a QR; anything else falls back to the Code 128
  `barcode_svg/2` used everywhere else. A QR-encoding failure also drops
  through to `barcode_svg/2` (which itself falls back to text alone).
  """
  def answer_code_svg(value, opts \\ []) do
    if qr_url?(value) do
      qr_svg(value) || barcode_svg(value, opts)
    else
      barcode_svg(value, opts)
    end
  end

  @doc """
  Whether a barcode answer looks like a URL — the signal that the physical
  code a player scans is a QR rather than a linear barcode. Deliberately
  strict (an explicit http/https scheme) so only the obvious cases switch.
  """
  def qr_url?(value) when is_binary(value), do: String.match?(value, ~r{\A\s*https?://\S+\s*\z}i)

  def qr_url?(_), do: false

  defp qr_svg(value) do
    svg =
      value
      |> String.trim()
      |> EQRCode.encode()
      |> EQRCode.svg(width: 120)

    # Strip the XML prolog EQRCode prepends — invalid when inlined into HTML.
    svg
    |> String.replace(~r/^<\?xml[^>]*\?>\n?/, "")
    |> raw()
  rescue
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
