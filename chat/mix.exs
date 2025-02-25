defmodule Chat.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: application_mod()
    ]
  end

  defp application_mod do
    cond do
      System.get_env("POOL") ->
        {Chat.AcceptorPool.Application, []}

      # System.get_env("THOUSAND_ISLAND") ->
      #   {Chat.ThousandIsland.Application, []}

      true ->
        {Chat.Application, []}
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
