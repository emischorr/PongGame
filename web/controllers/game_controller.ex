defmodule Pong.GameController do
  use Pong.Web, :controller

  alias Pong.Game

  def index(conn, _) do
    games = Repo.all(Game)
    render(conn, "index.html", games: games)
  end

  def play(conn, %{"id" => id} = params) do
    case game = Repo.get(Game, id) do
      nil -> redirect(conn, to: game_path(conn, :index))
      _ -> render conn, "show.html", game: game, mode: "player"
    end
  end

  def spectate(conn, %{"id" => id} = params) do
    case game = Repo.get(Game, id) do
      nil -> redirect(conn, to: game_path(conn, :index))
      _ -> render conn, "show.html", game: game, mode: "spectator"
    end
  end

  def control(conn, %{"id" => id}) do
    case game = Repo.get(Game, id) do
      nil -> redirect(conn, to: game_path(conn, :index))
      _ -> render conn, "control.html", game: game
    end
  end

  def new(conn, _) do
    changeset = Game.changeset(%Game{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"game" => game_params}) do
    changeset = Game.changeset(%Game{}, game_params)

    case Repo.insert(changeset) do
      {:ok, _game} ->
        conn
        |> put_flash(:info, "Game created successfully.")
        |> redirect(to: game_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

end
