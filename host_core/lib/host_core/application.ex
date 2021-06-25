defmodule HostCore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  require Logger

  use Application

  @prefix_var "WASMCLOUD_LATTICE_PREFIX"
  @default_prefix "default"

  def config!() do
    providers = [
      %Vapor.Provider.Env{
        bindings: [
          {:lattice_prefix, @prefix_var, default: @default_prefix},
          {:rpc_host, "WASMCLOUD_RPC_HOST", default: "0.0.0.0"},
          {:rpc_port, "WASMCLOUD_RPC_PORT", default: 4222, map: &String.to_integer/1},
          {:rpc_user, "WASMCLOUD_RPC_USER", default: ""},
          {:rpc_pass, "WASMCLOUD_RPC_PASS", default: ""},
          {:rpc_token, "WASMCLOUD_RPC_TOKEN", default: ""},
          {:rpc_seed, "WASMCLOUD_RPC_SEED", default: ""},
          {:rpc_jwt, "WASMCLOUD_RPC_JWT", default: ""},
          {:ctl_host, "WASMCLOUD_CTL_HOST", default: "0.0.0.0"},
          {:ctl_port, "WASMCLOUD_CTL_PORT", default: 4222, map: &String.to_integer/1},
          {:ctl_user, "WASMCLOUD_CTL_USER", default: ""},
          {:ctl_pass, "WASMCLOUD_CTL_PASS", default: ""},
          {:ctl_token, "WASMCLOUD_CTL_TOKEN", default: ""},
          {:ctl_seed, "WASMCLOUD_CTL_SEED", default: ""},
          {:ctl_jwt, "WASMCLOUD_CTL_JWT", default: ""}
        ]
      }
    ]

    Vapor.load!(providers)
  end

  def start(_type, _args) do
    config = config!()

    children = [
      # Starts a worker by calling: HostCore.Worker.start_link(arg)
      # {HostCore.Worker, arg}
      {Registry, keys: :unique, name: Registry.ProviderRegistry},
      {Registry, keys: :duplicate, name: Registry.ActorRegistry},
      {HostCore.Host, config},
      {HostCore.Providers.ProviderSupervisor, strategy: :one_for_one, name: ProviderRoot},
      {HostCore.Actors.ActorSupervisor, strategy: :one_for_one, name: ActorRoot},
      {HostCore.Linkdefs.Manager, strategy: :one_for_one, name: LinkdefsManager},
      {HostCore.Claims.Manager, strategy: :one_for_one, name: ClaimsManager},
      # Handle advertised link definitions and corresponding queries
      Supervisor.child_spec(
        {Gnat.ConsumerSupervisor,
         %{
           connection_name: :lattice_nats,
           module: HostCore.Linkdefs.Server,
           subscription_topics: [
             %{topic: "wasmbus.rpc.#{config.lattice_prefix}.linkdefs.put"},
             %{topic: "wasmbus.rpc.#{config.lattice_prefix}.linkdefs.del"},
             %{
               topic: "wasmbus.rpc.#{config.lattice_prefix}.linkdefs.get",
               queue_group: "wasmbus.rpc.#{config.lattice_prefix}.linkdefs.get"
             }
           ]
         }},
        id: :linkdefs_consumer_supervisor
      ),
      # Handle advertised PK->Claims maps and corresponding queries
      Supervisor.child_spec(
        {Gnat.ConsumerSupervisor,
         %{
           connection_name: :lattice_nats,
           module: HostCore.Claims.Server,
           subscription_topics: [
             %{topic: "wasmbus.rpc.#{config.lattice_prefix}.claims.put"},
             %{
               topic: "wasmbus.rpc.#{config.lattice_prefix}.claims.get",
               queue_group: "wasmbus.rpc.#{config.lattice_prefix}.claims.get"
             }
           ]
         }},
        id: :claims_consumer_supervisor
      ),
      # Handle advertised OCI->public key reference maps and corresponding queries
      Supervisor.child_spec(
        {Gnat.ConsumerSupervisor,
         %{
           connection_name: :lattice_nats,
           module: HostCore.Refmaps.Server,
           subscription_topics: [
             %{topic: "wasmbus.rpc.#{config.lattice_prefix}.refmaps.put"},
             %{
               topic: "wasmbus.rpc.#{config.lattice_prefix}.refmaps.get",
               queue_group: "wasmbus.rpc.#{config.lattice_prefix}.refmaps.get"
             }
           ]
         }},
        id: :refmaps_consumer_supervisor
      )
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HostCore.Supervisor]

    Logger.info("Starting Host Core")
    Supervisor.start_link(children, opts)
  end
end
