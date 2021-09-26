defmodule Bonfire.TaxonomySeeder.Migrations do
  use Ecto.Migration

  require Logger

  # alias Pointers.ULID
  alias CommonsPub.Repo

  @app_path File.cwd!
  @table "taxonomy_tag"

  def try_dotsql_execute(filename, mode) do
    path = filename

    case File.stat(path) do
      {:ok, _} ->
        dotsql_execute(path, mode)

      {:error, :enoent} ->
        Logger.info("SQL file for taxonomy module not found in current dir: " <> path)

        path = "overlay/" <> filename |> Path.expand(__DIR__)

        case File.stat(path) do
          {:ok, _} ->
            dotsql_execute(path, mode)

          {:error, :enoent} ->
            Logger.info("SQL file for taxonomy module not found in extension's /lib/overlay: " <> path)

            path = "priv/"<> filename |> Path.expand(@app_path)

            case File.stat(path) do
              {:ok, _} ->
                Logger.info("SQL file for taxonomy module found in extensions's /priv directory: " <> path)

                dotsql_execute(path, mode)

              {:error, :enoent} ->

                Logger.warn("SQL file for taxonomy module not found in extensions's /priv directory: " <> path)

                path = "../../priv/"<> filename |> Path.expand(@app_path)

                case File.stat(path) do
                  {:ok, _} ->

                    Logger.info("SQL file for taxonomy module found in app's /priv directory: " <> path)

                    dotsql_execute(path, mode)

                  {:error, :enoent} -> Logger.error("SQL file for taxonomy module not found in app's /priv directory: " <> path)
                end
              end
        end
    end
  end

  def dotsql_execute(filename, mode) do
    sqlines = String.split(File.read!(filename), ";\n")
    Enum.each(sqlines, &sql_execute(&1, mode))
    flush()
  end

  def sql_execute(sql, :migration) do
    execute(sql)
    flush()
  end

  def sql_execute(sql, :seed) do
    Ecto.Adapters.SQL.query!(
      Repo,
      sql
    )
  end

  # cleanup deprecated stuff
  def remove_pointer do
    alter table(@table) do
      remove_if_exists(:pointer_id, :uuid)
    end

    Pointers.Migration.drop_pointer_trigger(@table)
    CommonsPub.ReleaseTasks.remove_meta_table(@table)
  end

  def add_category do
    alter table(@table) do
      add_if_not_exists(:category_id, :uuid)
    end
  end

  def up do
    execute("DROP TABLE IF EXISTS " <> @table <> " CASCADE")
    try_dotsql_execute("tags.schema.sql", :migration)
    ingest_data(:migration)
    # add_category()
  end

  def ingest_data(mode) do
    try_dotsql_execute("seed_data/tags.data.sql", mode)
  end

  def down do
    try_dotsql_execute("tags.down.sql", :migration)
  end
end
