defmodule Bonfire.TaxonomySeeder.ImportBatch do
  import Bonfire.Common.Config, only: [repo: 0]

  @tags_index_name "taxonomy_tags"

  def import(subsection, repo \\ repo())

  def import("haha", repo) do
    batch(repo, "=2")
  end

  def import("needs", repo) do
    batch(repo, "=3")
  end

  def import("skills", repo) do
    batch(repo, "=4")
  end

  def batch(repo \\ repo(), q_filter \\ "is null") do
    Bonfire.Search.Indexer.init_index(@tags_index_name)

    {:ok, tags} = repo.query("WITH RECURSIVE taxonomy_tags_tree AS
    (SELECT id, name, parent_tag_id, CAST(name As varchar(1000)) As name_crumbs, summary
    FROM taxonomy_tag
    WHERE parent_tag_id " <> q_filter <> "
    UNION ALL
    SELECT si.id,si.name,
      si.parent_tag_id,
      CAST(sp.name_crumbs || '->' || si.name As varchar(1000)) As name_crumbs,
      si.summary
    FROM taxonomy_tag As si
      INNER JOIN taxonomy_tags_tree AS sp
      ON (si.parent_tag_id = sp.id)
    )
    SELECT id, name, name_crumbs, summary
    FROM taxonomy_tags_tree
    ORDER BY name_crumbs;
    ")

    # results = []

    for item <- tags.rows do
      [id, name, name_crumbs, summary] = item
      # obj = %{id: id, name: name, name_crumbs: name_crumbs, summary: summary}

      ## add to search index as is
      # Bonfire.Search.Indexer.index_objects(obj, @tags_index_name, false)

      IO.puts(Bonfire.TaxonomySeeder.TaxonomyTags.shorten(name))
      IO.puts(Bonfire.TaxonomySeeder.TaxonomyTags.username(name))

      ## import into Categories
      Bonfire.TaxonomySeeder.TaxonomyTags.maybe_make_category(nil, id)

      # results = results ++ [obj]
    end

    # Search.Indexer.index_objects(results, @tags_index_name)
  end

  def delete_imported() do
    Bonfire.Common.Repo.query(
      "delete from category where id in (select id from bonfire_tag where facet='Topic')"
    )

    Bonfire.Common.Repo.query(
      "delete from pointers_pointer where id in (select category.id from taxonomy_tag inner join category on category.id=taxonomy_tag.category_id)"
    )

    Bonfire.Common.Repo.query(
      "delete from bonfire_data_identity_character where id in (select category.id from taxonomy_tag inner join category on category.id=taxonomy_tag.category_id)"
    )
  end
end
