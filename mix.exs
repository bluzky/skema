defmodule Skema.MixProject do
  use Mix.Project

  def project do
    [
      app: :skema,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      package: package(),
      name: "Skema",
      description: description(),
      source_url: "https://github.com/bluzky/skema",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: ["Dung Nguyen"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/bluzky/skema"}
    ]
  end

  defp description do
    "Phoenix request params validation library"
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:valdi, "~> 0.5"},
      {:ex_doc, "~> 0.27", only: [:dev]},
      {:excoveralls, "~> 0.16", only: :test},
      {:styler, "~> 0.11", only: [:dev, :test], runtime: false},
      {:decimal, "~> 2.1"}
    ]
  end
end
