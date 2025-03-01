defmodule WasmcloudHostWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :wasmcloud_host

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_wasmcloud_host_key",
    signing_salt: "oIfMIYiq"
  ]

  socket("/socket", WasmcloudHostWeb.UserSocket,
    websocket: true,
    longpoll: false
  )

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug(Plug.Static,
    at: "/",
    from: :wasmcloud_host,
    gzip: false,
    only: ~w(css fonts images js coreui favicon.ico robots.txt)
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(WasmcloudHostWeb.Router)

  def init(_key, config) do
    host = System.get_env("DASHBOARD_HOST")

    if host != nil do
      {:ok, Keyword.put(config, :url, host: host)}
    else
      {:ok, config}
    end
  end
end
