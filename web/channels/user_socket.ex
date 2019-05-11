defmodule DungeonCrawl.UserSocket do
  use Phoenix.Socket

  ## Channels
  # channel "room:*", DungeonCrawl.RoomChannel
  channel "dungeons:*", DungeonCrawl.DungeonChannel

  ## Transports
  transport :websocket, Phoenix.Transports.WebSocket
  # transport :longpoll, Phoenix.Transports.LongPoll

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @max_age 2 * 7 * 24 * 60 * 60

  def connect(%{"token" => token}, socket) do
    case Phoenix.Token.verify(socket, "user hash socket", token, max_age: @max_age) do
      {:ok, user_id_hash} ->
        {:ok, assign(socket, :user_id_hash, user_id_hash)}
      {:error, _reason} ->
        :error
    end
  end
  def connect(_params, _socket), do: :error

  def id(socket), do: "users_socket:#{socket.assigns.user_id_hash}"
end
