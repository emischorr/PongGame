defmodule Pong.Plugs.Authenticate do
  require Logger
  import Plug.Conn
  import Ecto.Query, only: [from: 2]
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]

  def init(options) do
    options
  end

  def call(conn, _options) do
    case get_session(conn, :user_id) |> get_user do
      {:ok, user} ->
        Logger.debug "Set current_user: #{user.name}"
        conn |> assign(:current_user, user)
      {:error, :not_authorized} ->
        conn |> redirect(to: "/sessions/new")
      {:error, :not_found} ->
        Logger.debug "User not found!"
        conn |> redirect(to: "/account/signup")
    end
  end

  defp get_user(user_id = nil) do
    {:error, :not_authorized}
  end

  defp get_user(user_id) do
    case user = Pong.Repo.get(Pong.User, user_id) do
      nil -> {:error, :not_found}
      _ -> { :ok, user }
    end
  end

end
