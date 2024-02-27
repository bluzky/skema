[
  import_deps: [],
  subdirectories: ["priv/*/migrations"],
  plugins: [Styler],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
]
