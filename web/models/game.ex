defmodule Pong.Game do
  use Pong.Web, :model

  schema "games" do
    field :name, :string, null: false, default: "public game"
    field :description, :string
    field :max_players, :integer, null: false, default: 2

    timestamps
  end

  @required_fields ~w(name max_players)
  @optional_fields ~w(description)

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
