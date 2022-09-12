# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.TaxonomySeeder.TaxonomyTag do
  use Ecto.Schema

  alias Ecto.Changeset
  alias Bonfire.TaxonomySeeder.TaxonomyTag

  @type t :: %__MODULE__{}
  @required ~w(name)a
  @cast @required ++ ~w(summary parent_tag_id category_id)a

  # primary key is an integer
  @primary_key {:id, :id, autogenerate: true}
  schema "taxonomy_tag" do
    # field(:id, :string)
    field(:name, :string)
    field(:summary, :string)
    # field(:parent_tag_id, :integer)
    belongs_to(:parent_tag, TaxonomyTag, type: :id)

    belongs_to(:category, Bonfire.Classify.Category,
      references: :id,
      type: Pointers.ULID,
      foreign_key: :category_id
    )

    many_to_many(:related, TaxonomyTag,
      join_through: "taxonomy_tag_related",
      join_keys: [tag_id: :id, related_tag_id: :id]
    )

    # field(:pointer_id, Pointers.ULID) # optional pointer ID for the tag (only needed once a tage is actually used)
    # belongs_to(:pointer, Pointer, references: :pointer_id, type: Pointers.ULID) # optional pointer ID for the tag (only needed once a tage is actually used)
    # has_one(:character, CommonsPub.Characters.Character, references: :pointer_id, foreign_key: :characteristic_id)
  end

  def update_changeset(
        %TaxonomyTag{} = tag,
        attrs
      ) do
    tag
    |> Changeset.cast(attrs, @cast)
    |> common_changeset()
  end

  defp common_changeset(changeset) do
    changeset

    # |> Changeset.foreign_key_constraint(:pointer_id, name: :taxonomy_tag_pointer_id_fkey)
    # |> change_public()
    # |> change_disabled()
  end

  def context_module, do: Bonfire.TaxonomySeeder.TaxonomyTags

  def queries_module, do: Bonfire.TaxonomySeeder.TaxonomyTag.Queries

  def follow_filters, do: [:default]
end
