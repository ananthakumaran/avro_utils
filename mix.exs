defmodule AvroUtils.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :avro_utils,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Avro BigQuery utility library",
      package: package(),
      docs: docs(),
      dialyzer: [
        plt_add_deps: :transitive,
        flags: [:unmatched_returns, :race_conditions, :error_handling]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:erlavro, "~> 2.8"},
      {:jason, "~> 1.0"},
      {:ex_doc, "~> 0.20", only: :dev},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      {:stream_data, "~> 0.1", only: [:test, :dev]},
      {:randex, "~> 0.4", only: :test},
      {:google_api_big_query, "~> 0.4", only: :test},
      {:goth, "~> 1.1", only: :test},
      {:jose, "~> 1.9.0", only: :test},
      {:hackney, "~> 1.13", only: :test},
      {:temp, "~> 0.4", only: :test}
    ]
  end

  defp package do
    %{
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/ananthakumaran/avro_utils"},
      maintainers: ["ananthakumaran@gmail.com"]
    }
  end

  defp docs do
    [
      source_url: "https://github.com/ananthakumaran/fdb",
      source_ref: "v#{@version}",
      main: AvroUtils,
      extras: ["README.md"]
    ]
  end
end
