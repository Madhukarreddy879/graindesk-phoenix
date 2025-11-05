# Use the official Elixir image with Debian for better OpenSSL compatibility
FROM elixir:1.17-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    npm \
    git \
    python3 \
    nodejs \
    && rm -rf /var/lib/apt/lists/*

# Prepare build directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install dependencies with the non-root user
RUN groupadd -r app -g 1000 && \
    useradd -r -g app -u 1000 app

# Copy mix files
COPY mix.exs mix.lock ./
COPY config config

# Install all dependencies (including dev for asset compilation)
RUN mix deps.get

# Copy assets
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix ./assets ci

# Copy source code
COPY . .

# Install and compile assets (needs dev deps for tailwind/esbuild)
RUN mix assets.deploy

# Clean up dev dependencies and keep only production ones
RUN mix deps.clean --unused --only prod
RUN mix deps.get --only prod
RUN mkdir config/prod.secret.exs

# Compile the application in production mode
ENV MIX_ENV=prod
RUN mix compile --force

# Prepare release
COPY --chown=app:app . .
RUN mix release --path /opt/app

# Prepare a new release image
FROM ubuntu:22.04 AS app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    tzdata \
    openssl \
    libncurses5 \
    postgresql-client \
    libstdc++6 \
    libgcc-s1 \
    ca-certificates \
    curl \
    wkhtmltopdf \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/app

# Create non-root user
RUN groupadd -r app -g 1000 && \
    useradd -r -g app -u 1000 app

# Copy the release from the builder stage
COPY --from=builder --chown=app:app /opt/app .

USER app

# Set environment variables
ENV PORT=4000
ENV ECTO_IPV6=false
ENV ECTO_POOL_SIZE=10
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

# Start the application
CMD ["bin/rice_mill", "start"]