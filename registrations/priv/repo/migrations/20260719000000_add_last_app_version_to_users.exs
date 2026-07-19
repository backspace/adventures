defmodule Registrations.Repo.Migrations.AddLastAppVersionToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # The client's version+build (e.g. "1.0.0+2403"), stamped on the
      # app-open telemetry ping from the X-Client-Version header. Lets us see
      # which client builds are live — the reliable signal for compat drift,
      # since handled errors never reach Sentry.
      add(:last_app_version, :string)
    end
  end
end
