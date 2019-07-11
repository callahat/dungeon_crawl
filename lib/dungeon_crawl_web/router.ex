defmodule DungeonCrawlWeb.Router do
  use DungeonCrawl.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug DungeonCrawlWeb.Auth, repo: DungeonCrawl.Repo
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DungeonCrawlWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    # TODO: refactor to use the standard resource words
    get "/crawler", CrawlerController, :show
    post "/crawler", CrawlerController, :create
    post "/crawler/join", CrawlerController, :join
    delete "/crawler", CrawlerController, :destroy
    put  "/crawler", CrawlerController, :act

    resources "/user", UserController, singleton: true
    resources "/sessions", SessionController, only: [:new, :create, :delete]
    resources "/dungeons", DungeonController
      post    "/dungeons/:id/new_version", DungeonController, :new_version, as: :dungeon_new_version
      put     "/dungeons/:id/activate", DungeonController, :activate, as: :dungeon_activate
    
  end

  scope "/manage", DungeonCrawlWeb do
    pipe_through [:browser, :authenticate_user, :verify_user_is_admin]

    resources "/users", ManageUserController
    resources "/dungeons", ManageDungeonController, except: [:edit, :update]
    resources "/tile_templates", ManageTileTemplateController
  end

  # Other scopes may use custom stacks.
  # scope "/api", DungeonCrawlWeb do
  #   pipe_through :api
  # end
end
