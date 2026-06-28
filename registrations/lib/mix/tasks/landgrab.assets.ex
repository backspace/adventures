defmodule Mix.Tasks.Landgrab.Assets do
  @moduledoc """
  Regenerate LANDGRAB image artifacts from the live Phoenix templates.

  Outputs:

  * `priv/static/images/landgrab/meta.png` — 1000×500 banner for
    `og:image` / `twitter:image`. Captured from `/?placeholder=true`
    and centre-cropped to the wordmark.
  * `../landgrab_app/assets/icon/icon.png` — 1024×1024 master image
    consumed by `flutter_launcher_icons`. Captured from `/_icon` (a
    dedicated layout-less route that renders the stacked LANDGRAB
    wordmark on a `#0a0a0a` square).

  After writing the icon master, this task also runs
  `flutter pub run flutter_launcher_icons` in the mobile app dir so
  per-platform sizes (iOS asset catalog, Android mipmap-*) are
  regenerated in lockstep.

  ## Requirements

  * `mix phx.server` running on http://localhost:4000 (any env, but
    `dev` is the usual choice). The task exits with a clear error if
    it can't reach the server.
  * macOS — uses Homebrew/Apple `sips` for cropping and the bundled
    Google Chrome at the canonical path for headless screenshots.
  * `flutter` on PATH if you want the per-platform fan-out step.

  ## Usage

      mix landgrab.assets
  """
  use Mix.Task

  @chrome "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  @base_url "http://localhost:4000"
  @og_path "priv/static/images/landgrab/meta.png"
  @icon_path "../landgrab_app/assets/icon/icon.png"

  @shortdoc "Regenerate LANDGRAB OG image + app icon from live templates"

  @impl Mix.Task
  def run(_args) do
    ensure_server_up()
    capture_og()
    capture_icon()
    fan_out_flutter_icons()
    Mix.shell().info("Done.")
  end

  defp ensure_server_up do
    case System.cmd("curl", ["-sS", "-o", "/dev/null", "-w", "%{http_code}", @base_url],
           stderr_to_stdout: true
         ) do
      {"200" <> _, 0} ->
        :ok

      {code, _} ->
        Mix.raise("""
        Could not reach Phoenix at #{@base_url} (curl said #{inspect(code)}).
        Start the server first: `mix phx.server`
        """)
    end
  end

  defp capture_og do
    File.mkdir_p!(Path.dirname(@og_path))
    src = Path.join(System.tmp_dir!(), "landgrab-hero.png")
    # Captured at the hero's native 8:5 aspect so the wordmark lands
    # dead-centre; the crop then trims top/bottom margins down to the
    # wordmark band.
    chrome(src, "1200,750", "#{@base_url}/?placeholder=true")
    sips_crop(src, "500", "1000", @og_path)
    File.rm(src)
    Mix.shell().info("Wrote OG image → #{@og_path}")
  end

  defp capture_icon do
    File.mkdir_p!(Path.dirname(@icon_path))
    # The `/_icon` route is already exactly square, so no crop needed —
    # capture straight into the destination.
    chrome(@icon_path, "1024,1024", "#{@base_url}/_icon")
    Mix.shell().info("Wrote app icon → #{@icon_path}")
  end

  defp fan_out_flutter_icons do
    Mix.shell().info("Running flutter_launcher_icons in ../landgrab_app …")

    {output, status} =
      System.cmd("flutter", ["pub", "run", "flutter_launcher_icons"],
        cd: "../landgrab_app",
        stderr_to_stdout: true
      )

    if status != 0 do
      Mix.shell().error(output)
      Mix.raise("flutter_launcher_icons failed (exit #{status})")
    end
  end

  defp chrome(out, size, url) do
    args = [
      "--headless",
      "--disable-gpu",
      "--hide-scrollbars",
      "--window-size=#{size}",
      "--screenshot=#{out}",
      url
    ]

    {output, status} = System.cmd(@chrome, args, stderr_to_stdout: true)

    if status != 0 do
      Mix.shell().error(output)
      Mix.raise("Chrome screenshot failed for #{url} (exit #{status})")
    end
  end

  defp sips_crop(src, height, width, dst) do
    {output, status} =
      System.cmd("sips", ["-c", height, width, src, "--out", dst], stderr_to_stdout: true)

    if status != 0 do
      Mix.shell().error(output)
      Mix.raise("sips crop failed (exit #{status})")
    end
  end
end
