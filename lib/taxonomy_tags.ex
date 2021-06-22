defmodule Bonfire.TaxonomySeeder.TaxonomyTags do
  # import Ecto.Query
  # alias Ecto.Changeset
  require Logger


  alias Bonfrie.GraphQL.Page

  import Bonfire.Common.Config, only: [repo: 0]

  # alias CommonsPub.Users.User
  alias Bonfire.TaxonomySeeder.TaxonomyTag
  alias Bonfire.TaxonomySeeder.TaxonomyTag.Queries

  # alias CommonsPub.Characters

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  def one(filters), do: repo().single(Queries.query(TaxonomyTag, filters))

  def get(id), do: one(id: id, preload: :parent_tag, preload: :category)

  def many(filters \\ []), do: {:ok, repo().many(Queries.query(TaxonomyTag, filters))}

  @doc """
  Retrieves an Page of tags according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(TaxonomyTag, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- repo().transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of tags according to various filters

  Used by:
  * GraphQL resolver bulk resolution
  """
  def pages(
        cursor_fn,
        group_fn,
        page_opts,
        base_filters \\ [],
        data_filters \\ [],
        count_filters \\ []
      )

  def pages(cursor_fn, group_fn, page_opts, base_filters, data_filters, count_filters) do
    Bonfire.GraphQL.Pagination.pages(
      Queries,
      TaxonomyTag,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  @doc "Takes an existing TaxonomyTag and makes it a category, if one doesn't already exist"
  def maybe_make_category(user, %TaxonomyTag{} = tag) do
    tag = repo().preload(tag, [:category, :parent_tag])

    # with Bonfire.Classify.Categories.one(taxonomy_tag_id: tag.id) do
    if !is_nil(tag.category_id) and
         Ecto.assoc_loaded?(tag.category) and
         !is_nil(tag.category.id) do
      # already exists
      {:ok, tag.category}
    else
      make_category(user, tag)
    end
  end

  def maybe_make_category(user, id) when is_number(id) do
    with {:ok, tag} <- get(id) do
      maybe_make_category(user, tag)
    end
  end

  def maybe_make_category(user, id) do
    maybe_make_category(user, String.to_integer(id))
  end

  defp make_category(user, %TaxonomyTag{parent_tag_id: parent_tag_id} = tag)
       when not is_nil(parent_tag_id) do
    tag = repo().preload(tag, [:category, :parent_tag])
    parent_tag = tag.parent_tag

    # create_tag = cleanup(tag)

    # IO.inspect(pointerise_parent: parent_tag)

    # pointerise the parent(s) first (recursively)
    with {:ok, parent_category} <- maybe_make_category(user, parent_tag) do
      # IO.inspect(parent_category: parent_category)

      create_tag =
        cleanup(tag)
        |> Map.merge(%{parent_category: parent_category})
        |> Map.merge(%{parent_category_id: parent_category.id})
        |> Map.merge(%{
          preferred_username: shorten(tag.name, 150) <> "-" <> shorten(parent_tag.name, 100)
        })

      # finally pointerise the child(ren), in hierarchical order
      create_category(user, tag, create_tag)
    else
      _e ->
        Logger.error("could not create parent tag")
        raise "stopping here to debug"
        # create the child anyway?
        # create_category(user, tag, create_tag)
    end
  end

  defp make_category(user, %TaxonomyTag{} = tag) do
    create_category(user, tag, cleanup(tag))
  end

  defp create_category(user, tag, attrs) do
    # IO.inspect(create_category: tag)

    repo().transact_with(fn ->
      # IO.inspect(create_category: tag)

      with {:ok, category} <- Bonfire.Classify.Categories.create(user, attrs),
           {:ok, _tag} <- update(user, tag, %{category: category, category_id: category.id}) do
        {:ok, category}
      end
    end)
  end

  @doc "Transform the generic fields of anything to be turned into a character."
  def cleanup(thing) do
    thing
    # convert to map
    # |> Map.put(:taxonomy_tag, thing)
    # |> Map.put(:taxonomy_tag_id, thing.id)
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    # use Thing name as facet/trope
    |> Map.put(:facet, "Category")
    |> Map.put(:name, shorten(thing.name))
    |> Map.put(:prefix, "+")
    # avoid reusing IDs
    |> Map.delete(:id)
  end

  def shorten(input, length \\ 244) do
    CommonsPub.Utils.Text.truncate(input, length)
  end

  def update(_user, %TaxonomyTag{} = tag, attrs) do
    repo().transact_with(fn ->
      #  {:ok, character} <- CommonsPub.Characters.update(user, tag.character, attrs)
      # :ok <- publish(tag, :updated)
      with {:ok, tag} <- repo().update(TaxonomyTag.update_changeset(tag, attrs)) do
        {:ok, tag}
      end
    end)
  end

  def update(_user, tag_id, attrs) when is_binary(tag_id) do
    repo().transact_with(fn ->
      with {:ok, tag} <- one(id: tag_id),
           {:ok, tag} <- repo().update(TaxonomyTag.update_changeset(tag, attrs)) do
        {:ok, tag}
      end
    end)
  end

end
