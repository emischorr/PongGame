defmodule Pong.Repo.Migrations.CreateGame do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :name, :string, null: false, default: "public game"
      add :description, :text
      add :max_players, :integer, default: 2

      timestamps
    end

  end
end
