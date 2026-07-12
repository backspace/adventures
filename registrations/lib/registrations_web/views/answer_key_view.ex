defmodule RegistrationsWeb.AnswerKeyView do
  use RegistrationsWeb, :view

  @doc """
  Render a barcode value as an inline Code 128 SVG. Code 128 covers
  full ASCII, so it round-trips whatever string the pole's physical
  barcode carried regardless of the original symbology — the scanner
  compares decoded strings, not symbologies.
  """
  def barcode_svg(value) do
    {:ok, svg} =
      value
      |> Barlix.Code128.encode!()
      |> Barlix.SVG.print(xdim: 2, height: 60)

    # Strip the XML prolog — invalid when inlined into an HTML page.
    svg
    |> String.replace(~r/^<\?xml[^>]*\?>\n?/, "")
    |> raw()
  end
end
