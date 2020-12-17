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
    get "/reference", PageController, :reference
    # TODO: refactor to use the standard resource words
    get "/crawler", CrawlerController, :show
    post "/crawler", CrawlerController, :create
    post "/crawler/join", CrawlerController, :join
    post "/crawler/avatar", CrawlerController, :avatar
    post "/crawler/validate_avatar", CrawlerController, :validate_avatar
    get "/crawler/:map_set_instance_id/:passcode", CrawlerController, :invite
    post "/crawler/:map_set_instance_id/:passcode", CrawlerController, :validate_invite
    delete "/crawler", CrawlerController, :destroy

    resources "/user", UserController, singleton: true
    resources "/sessions", SessionController, only: [:new, :create, :delete]
    resources "/dungeons", DungeonController do
        resources "/levels", DungeonMapController, only: [:new, :create, :edit, :update, :delete], as: "map"
          post    "/levels/:id/validate_map_tile", DungeonMapController, :validate_map_tile, as: "map"
          get     "/map_edge", DungeonMapController, :map_edge, as: "map"
      end
      post    "/dungeons/:id/new_version", DungeonController, :new_version, as: :dungeon_new_version
      put     "/dungeons/:id/activate", DungeonController, :activate, as: :dungeon_activate
      post    "/dungeons/:id/test_crawl", DungeonController, :test_crawl, as: :dungeon_test_crawl

    resources "/tile_templates", ManageTileTemplateController
      post    "/tile_templates/:id/new_version", ManageTileTemplateController, :new_version, as: :manage_tile_template_new_version
      put     "/tile_templates/:id/activate", ManageTileTemplateController, :activate, as: :manage_tile_template_activate
  end

  scope "/manage", DungeonCrawlWeb do
    pipe_through [:browser, :authenticate_user, :verify_user_is_admin]

    resources "/users", ManageUserController
    resources "/dungeons", ManageDungeonController, except: [:new, :create, :edit, :update]
    resources "/settings", SettingController, singleton: true, only: [:edit, :update]
#    resources "/tile_templates", ManageTileTemplateController
#      post    "/tile_templates/:id/new_version", ManageTileTemplateController, :new_version, as: :manage_tile_template_new_version
#      put     "/tile_templates/:id/activate", ManageTileTemplateController, :activate, as: :manage_tile_template_activate
  end

  # Other scopes may use custom stacks.
  # scope "/api", DungeonCrawlWeb do
  #   pipe_through :api
  # end
end
