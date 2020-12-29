defmodule Bonfire.Repo.Migrations.ImportQuantify do
  use Ecto.Migration

  def change do
    if Code.ensure_loaded?(Bonfire.TaxonomySeeder.Migrations) do
       Bonfire.TaxonomySeeder.Migrations.change
       Bonfire.TaxonomySeeder.Migrations.change_measure
    end
  end
end
