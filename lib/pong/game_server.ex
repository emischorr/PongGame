defmodule Pong.GameServer do
  use GenServer
  require Logger

  @update_time 33 # ~1/30 sec

  @paddle_speed 20
  @board_height 500
  @board_width 700

  @start_ball %{x: 50, y: 50, vx: 2, vy: 2}

  ### public api
  def start_link(game) do
    GenServer.start_link(__MODULE__, [], name: game)
  end

  def join_game(name, user) do
    p_name = String.to_atom(name)
    case Process.whereis(p_name) do
      nil ->
        {:ok, pid} = start_link(p_name)
        Logger.debug "Started new game server process: #{p_name}"
        GenServer.call(p_name, {:join, user})
      _pid ->
        GenServer.call(p_name, {:join, user})
    end
  end

  def leave_game(name, user) do
    p_name = String.to_atom(name)
    GenServer.call(p_name, {:leave, user})
  end

  def move(game, player, direction) do
    GenServer.call(game, {:move, String.to_atom(player), direction})
  end

  def pause(game) do
    GenServer.call(game, :pause)
  end

  def current_state(game) do
    GenServer.call(game, :current_state)
  end

  ### GenServer callbacks
  def init(_options) do
    state = %{
      players: %{},
      paddles: %{p1: %{x: 350, y: @board_height}, p2: %{x: 350, y: 0}},
      ball: @start_ball,
      game: %{running: false}
    }
    schedule_next_update
    {:ok, state}
  end

  def handle_call({:join, user}, _from, state) do
    new_state = state
    |> join(user)
    |> start
    {:reply, new_state, new_state}
  end

  def handle_call({:leave, user}, _from, state) do
    new_state = state |> leave(user)
    {:reply, new_state, new_state}
  end

  def handle_call({:move, player, direction}, _from, state) do
    new_pos_fun = case direction do
      :right -> &(&1 + @paddle_speed)
      _ -> &(&1 - @paddle_speed)
    end
    new_state = update_in state[:paddles][player].x, new_pos_fun
    {:reply, new_state, new_state}
  end

  def handle_call(:pause, _from, state) do
    {:reply, %{}, pause(state)}
  end

  def handle_call(:current_state, _from, state) do
    {:reply, state, state}
  end

  def handle_info(:update, state) do
    schedule_next_update
    {:noreply, update(state)}
  end

  # discard unknown messages
  def handle_info(_msg, state) do
    Logger.debug "Unknown message: #{_msg}"
    {:noreply, state}
  end

  ### internal logic
  defp join(state, user) do
    Logger.debug "Joining user #{user}... [current players: #{player_count(state)}]"
    case player_count(state) do
      0 -> put_in state[:players][:p1], user
      1 -> put_in state[:players][:p2], user
      _ -> state
    end
  end

  defp leave(state, user) do
    Logger.debug "User leaving... [current players: #{player_count(state)}]"
    #TODO: remove correct user/player
    case player_count(state) do
      2 -> update_in(state[:players], &Map.delete(&1, :p2))
      1 -> update_in(state[:players], &Map.delete(&1, :p1)) |> stop
      _ -> state
    end

  end

  defp player_count(state) do
    Enum.count state[:players]
  end

  defp start(state) do
    if !state[:game][:running] && player_count(state) > 0 do
      Logger.debug "Starting game... [current players: #{player_count(state)}]"
      state = put_in(state[:ball], @start_ball)
      put_in(state[:game][:running], true)
    else
      state
    end
  end

  defp stop(state) do
    put_in state[:game][:running], false
  end

  defp toggle_pause(state) do
    Logger.debug "Game #{state[:game][:running] && "unpaused" || "paused" }"
    update_in state[:game][:running], &(!&1)
  end

  # game loop
  defp update(state) do
    state
    |> move_ball
    |> calculate_direction
    |> broadcast
  end

  defp move_ball(state) do
    if state[:game][:running] do
      update_in state[:ball], &(%{x: &1.x + &1.vx, y: &1.y + &1.vy, vx: &1.vx, vy: &1.vy})
    else
      state
    end
  end

  def calculate_direction(state) do
    case ball_collides?(state) do
      {:collision, :top} -> update_in state[:ball], &(%{x: &1.x, y: &1.y, vx: &1.vx, vy: &1.vy * -1})
      {:collision, :bottom} -> update_in state[:ball], &(%{x: &1.x, y: &1.y, vx: &1.vx, vy: &1.vy * -1})
      {:collision, :right} -> update_in state[:ball], &(%{x: &1.x, y: &1.y, vx: &1.vx * -1, vy: &1.vy})
      {:collision, :left} -> update_in state[:ball], &(%{x: &1.x, y: &1.y, vx: &1.vx * -1, vy: &1.vy})
      _ -> state
    end
  end

  defp ball_collides?(%{paddles: paddles, ball: ball} = state) do
    case ball do
      %{x: 0, y: _} -> {:collision, :left}
      %{x: _, y: 0} -> {:collision, :top}
      %{x: @board_width, y: _} -> {:collision, :right}
      %{x: _, y: @board_height} -> {:collision, :bottom}
      _ -> {:no_collision}
    end
  end

  defp broadcast(state) do
    Pong.Endpoint.broadcast "games:public", "state:update", state
    state
  end

  defp schedule_next_update do
    Process.send_after(self(), :update, @update_time)
  end

end
