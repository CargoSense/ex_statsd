defmodule ExStatsD.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_statsd,
     version: "0.5.3",
     elixir: "~> 1.0",
     package: package(),
     deps: deps(),
     # Documentation
     name: "ex_statsd",
     source_url: "https://github.com/CargoSense/ex_statsd",
     docs: [readme: true, main: "overview"]]
  end

  defp package do
    [description: "A StatsD client for Elixir",
     maintainers: ["Bruce Williams"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/CargoSense/ex_statsd"}]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    application(Mix.env)
  end
  def application(:test) do
    [applications: []]
  end
  def application(_) do
    [applications: [],
     mod: {ExStatsD.Application, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:ex_doc, "~> 0.10", only: :dev},
     {:earmark, "~> 0.1", only: :dev}]
  end

end
