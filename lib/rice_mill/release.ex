defmodule RiceMill.Release do
  @moduledoc """
  Used for executing database release tasks when run in production without Mix
  installed.
  """
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()

    # Run seeds for all repos
    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _ ->
          # Load and run the seeds file
          Code.eval_file("priv/repo/seeds.exs")
        end)
    end
  end

  defp repos do
    Application.fetch_env!(:rice_mill, :ecto_repos)
  end

  defp load_app do
    Application.load(:riceMill)
  end
end
