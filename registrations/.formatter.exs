[
  import_deps: [:phoenix],
  inputs: ["*.{heex, ex,exs}", "{config,lib,priv,test}/**/*.{heex, ex,exs}"],
  plugins: [Phoenix.LiveView.HTMLFormatter]
]
