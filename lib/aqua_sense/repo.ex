defmodule AquaSense.Repo do
  use Ecto.Repo,
    otp_app: :aqua_sense,
    adapter: Ecto.Adapters.Postgres
end
