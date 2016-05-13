use Mix.Config

# Stop Logger from spewing stupid empty newlines in between messages
config :logger, :console,
  format: "$time $metadata[$level] $levelpad$message\n"

import_config "#{Mix.env}.exs"
