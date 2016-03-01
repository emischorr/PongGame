# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Pong.Repo.insert!(%Pong.SomeModel{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

Pong.Repo.insert!(%Pong.User{name: "Player1", email: "player1@pong", encrypted_password: Comeonin.Bcrypt.hashpwsalt("player1")})
Pong.Repo.insert!(%Pong.User{name: "Player2", email: "player2@pong", encrypted_password: Comeonin.Bcrypt.hashpwsalt("player2")})
