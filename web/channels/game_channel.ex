defmodule Pong.GameChannel do
  use Phoenix.Channel
  require Logger

  @doc """
  Authorize socket to subscribe and broadcast events on this channel & topic
  Possible Return Values
  `{:ok, socket}` to authorize subscription for channel for requested topic
  `:ignore` to deny subscription/broadcast on this channel
  for the requested topic
  """
  def join("games:lobby", payload, socket) do
    Process.flag(:trap_exit, true)
    :timer.send_interval(5000, :ping)
    send(self, {:after_join, payload})

    {:ok, socket}
  end

  def join("games:" <> game_id, _payload, socket) do
    Pong.GameServer.join_game(game_id, socket.assigns[:user_id])
    {:ok, assign(socket, :game_id, game_id)}
  end

  def handle_in("move:" <> direction, _payload, socket) do
    Logger.debug "[game: #{socket.assigns[:game_id]}] user #{socket.assigns[:user_id]} moved #{direction}"
    state = Pong.GameServer.move(String.to_atom(socket.assigns[:game_id]), socket.assigns[:user_id], String.to_atom(direction))
    # broadcast! socket, "state:update", state
    {:reply, :ok, socket}
  end

  def handle_in("game:pause", _payload, socket) do
    Pong.GameServer.pause(String.to_atom(socket.assigns[:game_id]))
    {:reply, :ok, socket}
  end

  def terminate(reason, socket) do
    # Logger.debug "> leave #{inspect reason}"
    Pong.GameServer.leave_game(socket.assigns[:game_id], socket.assigns[:user_id])
    :ok
  end

end
