# Use the official Elixir image with the latest version
FROM elixir:1.17-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base npm git python3 nodejs

# Prepare build directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install dependencies with the non-root user
RUN addgroup -g 1000 -S app && \
    adduser -S app -G app -u 1000

# Copy mix files
COPY mix.exs mix.lock ./
COPY config config

# Install dependencies
RUN mix deps.get --only prod
RUN mkdir config/prod.secret.exs

# Copy source code
COPY . .

# Install and compile assets
RUN mix assets.deploy

# Compile the application
RUN mix compile --force

# Prepare release
COPY --chown=app:app . .
RUN mix release --path /opt/app

# Prepare a new release image
FROM alpine:3.19 AS app

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs postgresql-client

WORKDIR /opt/app

# Create non-root user
RUN addgroup -g 1000 -S app && \
    adduser -S app -G app -u 1000

# Copy the release from the builder stage
COPY --from=builder --chown=app:app /opt/app .

USER app

# Set environment variables
ENV PORT=4000
ENV ECTO_IPV6=false
ENV ECTO_POOL_SIZE=10

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

# Start the application
CMD ["bin/rice_mill", "start"]