defmodule Pong.Router do
  use Pong.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :auth do
    plug Pong.Plugs.Authenticate
    plug Pong.Plugs.UserToken
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Pong do
    pipe_through :browser # Use the default browser stack

    get "/", GameController, :index

    resources "sessions", SessionController, only: [ :new, :create ], singleton: true
    get "logout", SessionController, :delete

    get "/account/signup", UserController, :new
    post "/account", UserController, :create
  end

  scope "/", Pong do
    pipe_through :browser
    pipe_through :auth

    resources "games", GameController
    get "/games/:id/:mode", GameController, :show

    put "/account", UserController, :update
    delete "/account", UserController, :delete
    get "/profile", UserController, :profile
  end

  # Other scopes may use custom stacks.
  # scope "/api", Pong do
  #   pipe_through :api
  # end
end
