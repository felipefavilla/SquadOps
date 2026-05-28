# ---- Build Stage ----
FROM elixir:1.18-otp-27-alpine AS builder

RUN apk add --no-cache build-base git nodejs npm

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

COPY assets/package.json assets/package-lock.json ./assets/
RUN npm ci --prefix assets

COPY . .

RUN npm run deploy --prefix assets
RUN mix phx.digest
RUN mix release

# ---- Runtime Stage ----
FROM alpine:3.20 AS runtime

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

RUN addgroup -S app && adduser -S app -G app
USER app

COPY --from=builder --chown=app:app /app/_build/prod/rel/squad_ops ./

ENV PHX_HOST=localhost
ENV PORT=4000

EXPOSE 4000

CMD ["/app/bin/squad_ops", "start"]
