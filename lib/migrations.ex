defmodule Bonfire.TaxonomySeeder.Migrations do
  use Ecto.Migration

  import Untangle

  # alias Pointers.ULID
  alias CommonsPub.Repo

  @app_path Bonfire.Common.Config.get(:root_path)
  @table "taxonomy_tag"

  def try_dotsql_execute(filename, mode) do
    path = filename

    case File.stat(path) do
      {:ok, _} ->
        dotsql_execute(path, mode)

      {:error, :enoent} ->
        debug("SQL file for taxonomy module not found in current dir: " <> path)

        path = ("overlay/" <> filename) |> Path.expand(__DIR__)

        case File.stat(path) do
          {:ok, _} ->
            dotsql_execute(path, mode)

          {:error, :enoent} ->
            debug(
              "SQL file for taxonomy module not found in extension's /lib/overlay: " <>
                path
            )

            path = ("priv/" <> filename) |> Path.expand(@app_path)

            case File.stat(path) do
              {:ok, _} ->
                debug(
                  "SQL file for taxonomy module found in extensions's /priv directory: " <>
                    path
                )

                dotsql_execute(path, mode)

              {:error, :enoent} ->
                warn(
                  "SQL file for taxonomy module not found in extensions's /priv directory: " <>
                    path
                )

                path =
                  ("../../priv/seed_data/" <> filename)
                  |> Path.expand(@app_path)

                case File.stat(path) do
                  {:ok, _} ->
                    debug(
                      "SQL file for taxonomy module found in app's /priv directory: " <>
                        path
                    )

                    dotsql_execute(path, mode)

                  {:error, :enoent} ->
                    error(
                      "SQL file for taxonomy module not found in app's /priv directory: " <>
                        path
                    )
                end
            end
        end
    end
  end

  def dotsql_read(filename) do
    String.split(File.read!(filename), ";\n")
  end

  def dotsql_execute(filename, mode) do
    dotsql_read(filename)
    |> Enum.each(&sql_execute(&1, mode))

    Ecto.Migration.flush()
  end

  def sql_execute(sql, :migration) do
    execute(sql)
    Ecto.Migration.flush()
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
    try_dotsql_execute("tags.data.sql", mode)
  end

  def down do
    try_dotsql_execute("tags.down.sql", :migration)
  end
end
