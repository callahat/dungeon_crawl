defmodule DungeonCrawl.Router do
  use DungeonCrawl.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug DungeonCrawl.Auth, repo: DungeonCrawl.Repo
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DungeonCrawl do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    resources "/user", UserController, singleton: true
    resources "/sessions", SessionController, only: [:new, :create, :delete]
    resources "/dungeons", DungeonController
  end

  scope "/manage", DungeonCrawl do
    pipe_through [:browser, :authenticate_user, :verify_user_is_admin]

    resources "/users", ManageUserController
  end

  # Other scopes may use custom stacks.
  # scope "/api", DungeonCrawl do
  #   pipe_through :api
  # end
end
