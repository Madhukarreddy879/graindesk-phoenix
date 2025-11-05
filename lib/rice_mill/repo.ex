defmodule RiceMill.Repo do
  use Ecto.Repo,
    otp_app: :rice_mill,
    adapter: Ecto.Adapters.Postgres
end
