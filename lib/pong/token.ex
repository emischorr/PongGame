defmodule Pong.Plugs.UserToken do
  require Logger
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _options) do
    if current_user = conn.assigns[:current_user] do
      token = Phoenix.Token.sign(conn, "user socket", current_user.id)
      Logger.debug "Set token for user #{current_user.name}: #{token}"
      assign(conn, :user_token, token)
    else
      conn
    end
  end

end
