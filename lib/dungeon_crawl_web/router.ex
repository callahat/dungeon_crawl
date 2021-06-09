defmodule DungeonCrawlWeb.Router do
  use DungeonCrawl.Web, :router
  import Phoenix.LiveDashboard.Router

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
    get "/reference", PageController, :reference
    # TODO: refactor to use the standard resource words
    get "/crawler", CrawlerController, :show
    post "/crawler", CrawlerController, :create
    post "/crawler/avatar", CrawlerController, :avatar
    post "/crawler/validate_avatar", CrawlerController, :validate_avatar
    get "/crawler/:dungeon_instance_id/:passcode", CrawlerController, :invite
    post "/crawler/:dungeon_instance_id/:passcode", CrawlerController, :validate_invite
    delete "/crawler", CrawlerController, :destroy

    resources "/user", UserController, singleton: true
    resources "/sessions", SessionController, only: [:new, :create, :delete]
    resources "/dungeons", DungeonController do
        resources "/levels", DungeonMapController, only: [:new, :create, :edit, :update, :delete], as: "level"
          post    "/levels/:id/validate_tile", DungeonMapController, :validate_tile, as: "level"
          get     "/level_edge", DungeonMapController, :level_edge, as: "level"
      end
      post    "/dungeons/:id/new_version", DungeonController, :new_version, as: :dungeon_new_version
      put     "/dungeons/:id/activate", DungeonController, :activate, as: :dungeon_activate
      post    "/dungeons/:id/test_crawl", DungeonController, :test_crawl, as: :dungeon_test_crawl

    post "/tile_shortlists", TileShortlistController, :create

    resources "/tile_templates", ManageTileTemplateController
      post    "/tile_templates/:id/new_version", ManageTileTemplateController, :new_version, as: :manage_tile_template_new_version
      put     "/tile_templates/:id/activate", ManageTileTemplateController, :activate, as: :manage_tile_template_activate

    get "/scores", ScoreController, :index
  end

  scope "/manage", DungeonCrawlWeb do
    pipe_through [:browser, :authenticate_user, :verify_user_is_admin]

    resources "/users", ManageUserController
    resources "/dungeons", ManageDungeonController, except: [:new, :create, :edit, :update]
    resources "/settings", SettingController, singleton: true, only: [:edit, :update]
    resources "/dungeon_processes", ManageDungeonProcessController, only: [:index, :show, :delete]
       get    "/dungeon_processes/:di_id/level_processes/:id", ManageLevelProcessController, :show
       delete "/dungeon_processes/:di_id/level_processes/:id", ManageLevelProcessController, :delete

    live_dashboard "/dashboard", metrics: DungeonCrawlWeb.Telemetry, ecto_repos: [DungeonCrawl.Repo]

#    resources "/tile_templates", ManageTileTemplateController
#      post    "/tile_templates/:id/new_version", ManageTileTemplateController, :new_version, as: :manage_tile_template_new_version
#      put     "/tile_templates/:id/activate", ManageTileTemplateController, :activate, as: :manage_tile_template_activate
  end

  # Other scopes may use custom stacks.
  # scope "/api", DungeonCrawlWeb do
  #   pipe_through :api
  # end
end
