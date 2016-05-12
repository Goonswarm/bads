FROM elixir
MAINTAINER Vincent Ambo <tazjin@gmail.com>

RUN mix do local.hex --force, local.rebar --force
RUN apt-get update && apt-get install -y git make

ENV MIX_ENV prod

ADD . /opt/bads
WORKDIR /opt/bads

RUN mix do deps.get, deps.compile, compile, release

CMD /opt/bads/rel/bads/bin/bads foreground
