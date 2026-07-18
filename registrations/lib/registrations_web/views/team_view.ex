defmodule RegistrationsWeb.TeamView do
  use RegistrationsWeb, :view

  @doc """
  Renders a team's join code as an inline QR-code SVG for the printable
  team cards. The QR encodes the bare code string, which is exactly what
  the app's join scanner expects.
  """
  def join_code_qr(nil), do: ""

  def join_code_qr(code) do
    code
    |> EQRCode.encode()
    |> EQRCode.svg(width: 180)
  end
end
