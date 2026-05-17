# syntax=docker/dockerfile:1
ARG ELIXIR_VERSION=1.17.2
ARG OTP_VERSION=27.0.1
ARG DEBIAN_VERSION=bookworm-20260505-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y \
    && apt-get install -y build-essential git curl ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g pnpm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN --mount=type=cache,target=/root/.hex \
    --mount=type=cache,target=/root/.mix \
    mix deps.get --only $MIX_ENV

RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN --mount=type=cache,target=/root/.hex \
    --mount=type=cache,target=/root/.mix \
    mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

WORKDIR /app/assets
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile
WORKDIR /app

RUN --mount=type=cache,target=/root/.mix \
    mix assets.setup
RUN mix assets.deploy
RUN mix compile

COPY config/runtime.exs config/

RUN mix release

FROM ${RUNNER_IMAGE}

RUN apt-get update -y \
    && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

ENV MIX_ENV="prod" \
    PHX_SERVER="true"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/registrations ./
COPY --chown=nobody:root bin/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

USER nobody

EXPOSE 4000

CMD ["/app/entrypoint.sh"]
