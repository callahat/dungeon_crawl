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
    get "/dungeons/old", DungeonController, :index_old, as: :old_dungeon
    get "/dungeons", DungeonController, :index
    get "/crawler", CrawlerController, :show
    post "/crawler", CrawlerController, :create
    post "/crawler/avatar", CrawlerController, :avatar
    post "/crawler/validate_avatar", CrawlerController, :validate_avatar
    get "/crawler/:dungeon_instance_id/:passcode", CrawlerController, :invite
    post "/crawler/:dungeon_instance_id/:passcode", CrawlerController, :validate_invite
    delete "/crawler", CrawlerController, :destroy

    resources "/user", UserController, singleton: true
    resources "/sessions", SessionController, only: [:new, :create, :delete]

    scope "/editor", Editor, as: :edit do
      get "/dungeons/export", DungeonController, :dungeon_export_list, as: :dungeon_export
      get "/dungeons/export/:id", DungeonController, :download_dungeon_export, as: :dungeon_export
      get "/dungeons/import", DungeonController, :dungeon_import, as: :dungeon_import

      scope "/dungeons" do
        resources "/", DungeonController do
            resources "/levels", LevelController, only: [:new, :create, :edit, :update, :delete], as: "level"
              post    "/levels/:id/validate_tile", LevelController, :validate_tile, as: "level"
              get     "/level_edge", LevelController, :level_edge, as: "level"
          end
          post    "/:id/export", DungeonController, :dungeon_export, as: :dungeon_export
          post    "/:id/new_version", DungeonController, :new_version, as: :dungeon_new_version
          put     "/:id/activate", DungeonController, :activate, as: :dungeon_activate
          post    "/:id/test_crawl", DungeonController, :test_crawl, as: :dungeon_test_crawl
      end

      resources "/equipment", EquipmentController

      resources "/sound/effects", EffectController

      post "/tile_shortlists", TileShortlistController, :create
      delete "/tile_shortlists", TileShortlistController, :delete

      resources "/tile_templates", TileTemplateController
        post    "/tile_templates/:id/new_version", TileTemplateController, :new_version, as: :tile_template_new_version
        put     "/tile_templates/:id/activate", TileTemplateController, :activate, as: :tile_template_activate
    end

    get "/scores", ScoreController, :index
  end

  scope "/admin", DungeonCrawlWeb.Admin, as: :admin do
    pipe_through [:browser, :authenticate_user, :verify_user_is_admin]

    resources "/users", UserController
    resources "/dungeons", DungeonController, except: [:new, :create, :edit, :update]
    resources "/settings", SettingController, singleton: true, only: [:edit, :update]
    resources "/dungeon_processes", DungeonProcessController, only: [:index, :show, :delete]
       get    "/dungeon_processes/:di_id/level_processes/:num/:plid", LevelProcessController, :show
       delete "/dungeon_processes/:di_id/level_processes/:num/:plid", LevelProcessController, :delete

    live_dashboard "/dashboard", metrics: DungeonCrawlWeb.Telemetry, ecto_repos: [DungeonCrawl.Repo]
  end

  # Other scopes may use custom stacks.
  # scope "/api", DungeonCrawlWeb do
  #   pipe_through :api
  # end
end
