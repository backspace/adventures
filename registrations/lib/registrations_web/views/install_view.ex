defmodule RegistrationsWeb.InstallView do
  use RegistrationsWeb, :view

  @doc """
  Inline QR-code SVG for an onboarding link. `viewbox: true` gives a
  scalable SVG (viewBox, no fixed dimensions) so CSS can blow it up to
  fill the page.
  """
  def qr(url) do
    url
    |> EQRCode.encode()
    |> EQRCode.svg(viewbox: true)
  end
end
