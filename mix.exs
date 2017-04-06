defmodule SSHKit.Mixfile do
  use Mix.Project

  @version "0.0.1"
  @source "https://github.com/bitcrowd/sshkit.ex"

  def project do
    [app: :sshkit,
     name: "sshkit",
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     source_url: @source,
     docs: [source_ref: "v#{@version}", main: "readme", extras: ["README.md"]],
     description: description(),
     deps: deps(),
     package: package()]
  end

  def application do
    [applications: [:logger, :ssh]]
  end

  defp deps do
    [{:credo, "~> 0.7", only: [:dev, :test]},
     {:ex_doc, "~> 0.14", only: [:dev], runtime: false},
     {:inch_ex, "~> 0.5", only: [:dev, :test]}]
  end

  defp description do
    "A toolkit for performing tasks on one or more servers, built on top of Erlang’s SSH application"
  end

  defp package do
    [maintainers: ["bitcrowd", "Paul Meinhardt", "Paulo Diniz", "Philipp Tessenow"],
     licenses: ["MIT"],
     links: %{"GitHub" => @source}]
  end
end
