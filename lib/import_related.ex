defmodule Bonfire.TaxonomySeeder.ImportRelated do
  import Bonfire.Common.Config, only: [repo: 0]

  def batch() do
    {:ok, tags} = Bonfire.TaxonomySeeder.TaxonomyTags.many(preload: :category)

    with_related =
      tags
      |> repo().preload([:related])
      |> Enum.reject(&(&1.related == []))

    # |> IO.inspect

    for %{category_id: tid} = tag when not is_nil(tid) <- with_related do
      for %{category_id: rid} = tag_related when not is_nil(rid) <- tag.related do
        Bonfire.Data.Assort.Ranked.changeset(%{item_id: rid, scope_id: tid})
        |> repo().insert_or_ignore()

        Bonfire.Data.Assort.Ranked.changeset(%{item_id: tid, scope_id: rid})
        |> repo().insert_or_ignore()
      end
    end
  end

  def check_imported() do
    {:ok, tags} = Bonfire.Tag.many()

    with_related =
      tags
      |> repo().preload([:profile, related: [:profile]])
      |> Enum.reject(&(&1.related == []))
      |> IO.inspect()
  end
end
