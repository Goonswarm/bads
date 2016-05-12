defmodule BADS do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Get application configuration
    config = Application.get_all_env(:bads)

    children = [
      #worker(BADS.LDAP, config[:ldap]),
      #worker(BADS.PhpBB, [], name: :phpbb),
      worker(BADS.Groups, [config[:phpbb]]),
      worker(:mysql, [config[:phpbb]]) ,
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BADS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
