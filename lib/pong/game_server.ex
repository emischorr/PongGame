defmodule Pong.GameServer do
  use GenServer
  require Logger

  @update_time 33 # ~1/30 sec
  @collision_shortcut_boundary 50 # in px

  @min_player_count 1

  @paddle_speed 20
  @paddle_len 100
  @paddle_width 5
  @board_height 700
  @board_width 700
  @ball_radius 5

  @start_ball %{x: 350, y: 350, vx: 5, vy: 6}

  ### public api
  def start_link(game) do
    GenServer.start_link(__MODULE__, [name: Atom.to_string(game)], name: game)
  end

  def join_game(name, user, mode) do
    p_name = String.to_atom(name)
    case Process.whereis(p_name) do
      nil ->
        {:ok, pid} = start_link(p_name)
        Logger.debug "Started new game server process: #{p_name}"
        GenServer.call(p_name, {:join, user, mode})
      _pid ->
        GenServer.call(p_name, {:join, user, mode})
    end
  end

  def leave_game(name, user) do
    p_name = String.to_atom(name)
    GenServer.call(p_name, {:leave, user})
  end

  def move(game, user_id, direction) do
    GenServer.call(game, {:move, user_id, direction})
  end

  def pause(game, user_id) do
    GenServer.call(game, {:pause, user_id})
  end

  def current_state(game) do
    GenServer.call(game, :current_state)
  end

  ### GenServer callbacks
  def init(options) do
    <<a::size(32), b::size(32), c::size(32)>> = :crypto.rand_bytes(12)
    :random.seed({a, b, c})

    state = %{
      players: %{},
      paddles: %{},
      balls: %{b1: @start_ball},
      game: %{running: false, name: options[:name]}
    }
    schedule_next_update
    {:ok, state}
  end

  def handle_call({:join, user, mode}, _from, state) do
    new_state = state
    |> join(user, mode)
    |> start
    {:reply, new_state, new_state}
  end

  def handle_call({:leave, user}, _from, state) do
    new_state = state |> leave(user)
    {:reply, new_state, new_state}
  end

  def handle_call({:move, user_id, direction}, _from, state) do
    player = player_pos(state, user_id)
    new_state = case direction do
      :right when player in [:p1, :p2] -> update_in state[:paddles][player].x, &(&1 + @paddle_speed)
      :left when player in [:p1, :p2] -> update_in state[:paddles][player].x, &(&1 - @paddle_speed)
      :up when player in [:p3, :p4] -> update_in state[:paddles][player].y, &(&1 - @paddle_speed)
      :down when player in [:p3, :p4] -> update_in state[:paddles][player].y, &(&1 + @paddle_speed)
      _ -> state
    end
    {:reply, new_state, new_state}
  end

  def handle_call({:pause, user_id}, _from, state) do
    player = player_pos(state, user_id)
    if player in [:p1, :p2, :p3, :p4] do
      {:reply, %{}, toggle_pause(state)}
    else
      {:reply, %{}, state}
    end
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
  defp join(state, user, mode) do
    case mode do
      :player ->
        Logger.debug "Joining user #{user} as player... [current players: #{player_count(state)}]"
        state |> add_player(user)
      _ ->
        Logger.debug "Joining user #{user} as spectator... [current players: #{player_count(state)}]"
        state
    end
  end

  defp leave(state, user) do
    Logger.debug "User leaving... [current players: #{player_count(state)}]"
    if player_count(state) > 0, do: remove_player(state, user)
    case player_count(state) do
      0 -> stop(state)
      _ -> state
    end
  end

  defp player_count(state) do
    Enum.count state[:players]
  end

  defp start(state) do
    if !state[:game][:running] do
      restart(state)
    else
      state
    end
  end

  defp restart(state) do
    if player_count(state) >= @min_player_count do
      Logger.debug "Starting game... [current players: #{player_count(state)}]"
      rand_fn = &(&1*:random.uniform+1)
      ball = @start_ball |> Map.update!(:vx, rand_fn) |> Map.update!(:vy, rand_fn)
      state = put_in(state[:balls], %{b1: ball})
      put_in(state[:game][:running], true)
    else
      state
    end
  end

  defp stop(state) do
    Logger.debug "Game stopped"
    put_in state[:game][:running], false
  end

  defp toggle_pause(state) do
    Logger.debug "Game #{state[:game][:running] && "paused" || "unpaused" }"
    update_in state[:game][:running], &(!&1)
  end

  # game loop
  defp update(state) do
    if state[:game][:running] do
      state
      |> move_ball
      |> check_collision
      |> check_points
      |> calculate_direction
      |> broadcast
    else
      state
    end
  end

  defp move_ball(state) do
    update_in state[:balls][:b1], &(%{x: &1.x + &1.vx, y: &1.y + &1.vy, vx: &1.vx, vy: &1.vy})
  end

  defp check_collision(state) do
    { state, ball_collides?(state) }
  end

  defp check_points({state, collision}) do
    #TOOD: check for points/lives/goals
    case collision do
      {:collision, side, :no} ->
        if !side_empty(state, side) do
          Logger.debug Atom.to_string(side)<>" side lost"
          { restart(state), {} }
        else
          { state, collision }
        end
      _ -> { state, collision }
    end
  end

  defp calculate_direction({state, collision}) do
    case collision do
      {:collision, :top, _} -> update_in state[:balls][:b1], &(%{x: &1.x, y: &1.y, vx: &1.vx, vy: &1.vy * -1})
      {:collision, :bottom, _} -> update_in state[:balls][:b1], &(%{x: &1.x, y: &1.y, vx: &1.vx, vy: &1.vy * -1})
      {:collision, :right, _} -> update_in state[:balls][:b1], &(%{x: &1.x, y: &1.y, vx: &1.vx * -1, vy: &1.vy})
      {:collision, :left, _} -> update_in state[:balls][:b1], &(%{x: &1.x, y: &1.y, vx: &1.vx * -1, vy: &1.vy})
      _ -> state
    end
  end

  defp ball_collides_wall?(%{paddles: paddles, balls: balls} = state) do
    collision = case {balls[:b1], Map.values(paddles)} do
      {%{x: x, y: y}, _} when x >= @collision_shortcut_boundary and x <= (@board_width - @collision_shortcut_boundary)
        and y >= @collision_shortcut_boundary and y <= (@board_height - @collision_shortcut_boundary) -> {:in_boundary} # short circuit evaluation
      # {%{x: x, y: y}, [%{x: px, y: py}]} when y in @board_height-10..@board_height and x in px-50..px+50 -> Logger.debug "hit"; {:collision, :bottom}
      {%{x: x, y: _}, _} when x <= 0 + @ball_radius -> {:collision, :left, :no}
      {%{x: _, y: y}, _} when y <= 0 + @ball_radius -> {:collision, :top, :no}
      {%{x: x, y: _}, _} when x >= @board_width - @ball_radius -> {:collision, :right, :no}
      {%{x: _, y: y}, _} when y >= @board_height - @ball_radius -> {:collision, :bottom, :no}
      {%{x: x, y: y}, _} -> {:no_wall, x, y}
    end
  end

  defp ball_collides?(%{paddles: paddles} = state) do
    case ball_collides_wall?(state) do
      {:in_boundary} -> {:no_collision}
      {:collision, side, _} -> {:collision, side, :no}
      {:no_wall, x, y} ->
        collisions = for {k, v} <- paddles do
          case {x, y, v.x, v.y, v.len} do
            # bottom paddle
            {x, y, px, py, plen} when py == @board_height
            and y >= @board_height-@ball_radius-@paddle_width and y <= @board_height-@ball_radius
            and x >= px-plen/2 and x <= px+plen/2 ->
              Logger.debug "hit bottom #{k}"; {:collision, :bottom, k}
            # top paddle
            {x, y, px, py, plen} when py == 0
            and y >= 0+@ball_radius and y <= @ball_radius+@paddle_width
            and x >= px-plen/2 and x <= px+plen/2 ->
              Logger.debug "hit top #{k}"; {:collision, :top, k}
            # left paddle
            {x, y, px, py, plen} when px == 0
            and x >= 0+@ball_radius and x <= @ball_radius+@paddle_width
            and y >= py-plen/2 and y <= py+plen/2 ->
              Logger.debug "hit left #{k}"; {:collision, :left, k}
            # right paddle
            {x, y, px, py, plen} when px == @board_width
            and x >= @board_height-@ball_radius-@paddle_width and x <= @board_height-@ball_radius
            and y >= py-plen/2 and y <= py+plen/2 ->
              Logger.debug "hit right #{k}"; {:collision, :right, k}
            # anything else
            _ -> {:no_collision}
          end
        end
        Enum.find collisions, {:no_collision}, fn x -> hd(Tuple.to_list(x)) == :collision end
    end
  end

  defp broadcast(state) do
    Pong.Endpoint.broadcast "games:"<>state[:game][:name], "state:update", state
    state
  end

  defp schedule_next_update do
    Process.send_after(self(), :update, @update_time)
  end

  defp side_empty(%{players: players} = state, side) do
    player = case side do
      :bottom -> :p1
      :top -> :p2
      :left -> :p3
      :right -> :p4
    end
    case Enum.find(players, fn p -> elem(p,0) == player end) do
      nil -> true
      _ -> false
    end
  end

  defp player_pos(%{players: players} = state, user_id) do
    case Enum.find(players, fn p -> elem(p,1) == user_id end) do
      nil -> :spectator
      player -> elem( player, 0 )
    end
  end

  defp add_player(%{players: players} = state, user) do
    # order in wich player seats are assigned
    player = Enum.find [:p3, :p2, :p1, :p4], fn player_pos -> !Map.has_key? players, player_pos end
    case player do
      nil -> state
      p ->
        state = put_in state[:players][p], user
        put_in state[:paddles][p], create_paddle(p)
    end
  end

  defp remove_player(%{players: players} = state, user_id) do
    player = player_pos(state, user_id)
    state = update_in( state[:players], &Map.delete(&1, player) )
    update_in( state[:paddles], &Map.delete(&1, player) )
  end

  defp create_paddle(player) when player in [:p1, :p2, :p3, :p4] do
    case player do
      :p1 -> %{x: @board_width/2, y: @board_height, pos: :bottom, len: @paddle_len}
      :p2 -> %{x: @board_width/2, y: 0, pos: :top, len: @paddle_len}
      :p3 -> %{x: 0, y: @board_height/2, pos: :left, len: @paddle_len}
      :p4 -> %{x: @board_width, y: @board_height/2, pos: :right, len: @paddle_len}
    end
  end

  defp set_paddle_length(state, paddle, length) do
    put_in state[:paddles][paddle][:len], length
  end

end
