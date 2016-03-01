defmodule Pong.SessionController do
  use Pong.Web, :controller

  alias Pong.User

  def new(conn, _) do
    changeset = User.changeset(%User{})
    render conn, "new.html", changeset: changeset
  end

  def create(conn, %{"user" => session}) do
    changeset = User.changeset %User{}, session
    if user = User.authenticate?(changeset) do
      conn
        |> put_session(:user_id, user.id)
        |> redirect(to: game_path(conn, :index))
    end
    render conn, "new.html", changeset: changeset
  end

  def delete(conn, _) do
    conn
      |> put_session(:user_id, nil)
      |> redirect(to: session_path(conn, :new))
  end

end
