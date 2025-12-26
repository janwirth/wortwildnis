defmodule Wortwildnis.MixProject do
  use Mix.Project

  def project do
    [
      app: :wortwildnis,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      consolidate_protocols: Mix.env() != :dev
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Wortwildnis.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:oban, "~> 2.0"},
      {:oban_web, "~> 2.0"},
      {:ash_ai, "~> 0.4"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:picosat_elixir, "~> 0.2"},
      {:dotenvy, "~> 0.7"},
      {:langchain, "~> 0.4.0"},
      # {:simple_sat, "~> 0.1"},
      {:ash_authentication, "~> 4.0"},
      {:ash_admin, "~> 0.13"},
      {:ash_postgres, "~> 2.0"},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:ash_phoenix, "~> 2.0"},
      # {:ash, "~> 3.0"},
      {:ash,
       github: "ash-project/ash", branch: "bug/preparation-calculation-using-args", override: true},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:phoenix, "~> 1.8.2"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:live_debugger, "~> 0.5.0", only: :dev},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:slugify, "~> 1.3.1"},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:phoenix_seo, "~> 0.1.11"},
      {:ash_oban, "~> 0.7"},
      {:gel, "~> 0.9"},
      {:deepl_ex, "~> 0.4.0"},
      {:essence, "~> 0.3.0"},
      {:html_entities, "~> 0.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ash.setup --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind wortwildnis", "esbuild wortwildnis"],
      "assets.deploy": [
        "tailwind wortwildnis --minify",
        "esbuild wortwildnis --minify",
        "copy_fonts",
        "phx.digest"
      ],
      copy_fonts: &copy_fonts/1,
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  defp copy_fonts(_) do
    source_dir = Path.join(["assets", "fonts"])
    target_dir = Path.join(["priv", "static", "assets", "fonts"])

    if File.exists?(source_dir) do
      File.mkdir_p!(target_dir)

      source_dir
      |> File.ls!()
      |> Enum.each(fn file ->
        source_path = Path.join(source_dir, file)
        target_path = Path.join(target_dir, file)

        if File.regular?(source_path) do
          File.cp!(source_path, target_path)
          Mix.shell().info("Copied #{file}")
        end
      end)
    end

    :ok
  end
end
