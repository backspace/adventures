defmodule RegistrationsWeb.AnswerKeyController do
  @moduledoc """
  Admin-only printable answer key: every pole with its barcode
  rendered as a scannable Code 128 SVG, plus each attached puzzlet's
  question and answer. Unattached puzzlets are listed at the end so
  the key is complete. Intended to be printed (or kept open on a
  phone) while checking content in the field.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab.Pole
  alias Registrations.Landgrab.Puzzlet

  plug RegistrationsWeb.Plugs.Admin

  def index(conn, _params) do
    puzzlet_order = from(z in Puzzlet, order_by: [asc: z.difficulty, asc: z.inserted_at])

    poles =
      Repo.all(
        from(p in Pole,
          order_by: [asc: p.label, asc: p.barcode],
          preload: [puzzlets: ^puzzlet_order]
        )
      )

    unattached =
      Repo.all(
        from(z in Puzzlet,
          where: is_nil(z.pole_id),
          order_by: [asc: z.difficulty, asc: z.inserted_at]
        )
      )

    render(conn, "index.html", poles: poles, unattached: unattached)
  end
end
