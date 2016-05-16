defmodule BADS.Mixfile do
  use Mix.Project

  def project do
    [app: :bads,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :mysql, :eldap, :crypto, :asn1],
     mod: {BADS, []}]
  end

  defp deps do
    [{:mysql, git: "https://github.com/mysql-otp/mysql-otp", ref: "20e258371"}]
  end
end
