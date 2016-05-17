use Mix.Config

# Logger configuration
config :logger,
  level: :info

# LDAP configuration
config :bads, :ldap,
  host: 'goon-ldap',
  port: 389

# phpBB target configuration
# Note that the MySQL driver users Erlang strings
config :bads, :phpbb,
  interval: 30,
  host: 'forum',
  database: 'tendollarbond',
  user: 'phpbb',
  password: :os.getenv('MARIADB_PASSWORD'),
  keepalive: true,
  name: {:local, :phpbb_db}
