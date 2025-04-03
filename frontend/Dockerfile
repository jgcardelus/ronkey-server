# ---- Build stage ----
FROM hexpm/elixir:1.18.3-erlang-25.3.2.19-alpine-3.20.6 AS build

RUN apk add --no-cache build-base npm git python3

WORKDIR /app

# Cache deps
COPY mix.exs mix.lock ./
COPY config config
RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get --only prod
RUN mix deps.compile

# Assets
COPY assets assets
RUN MIX_ENV=prod mix assets.deploy

# Build release
COPY lib lib
COPY priv priv
RUN MIX_ENV=prod mix release

# ---- Release stage ----
FROM alpine:3.18.0 AS app

RUN apk add --no-cache openssl ncurses-libs libstdc++

WORKDIR /app

COPY --from=build /app/_build/prod/rel/frontend .
ENV HOME=/app

CMD ["bin/frontend", "start"]
