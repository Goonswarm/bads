use Mix.Config

# LDAP configuration
config :bads, :ldap,
  host: 'localhost',
  port: 3389

# phpBB target configuration
# Note that the MySQL driver users Erlang strings
config :bads, :phpbb,
  interval: 5,
  host: '127.0.0.1',
  database: 'phpbb3',
  user: 'phpbb',
  keepalive: true,
  password: :os.getenv('MARIADB_PASSWORD'),
  name: {:local, :phpbb_db}
