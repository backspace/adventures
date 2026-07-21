defmodule Registrations.Repo.Migrations.AddLiberationPhase do
  use Ecto.Migration

  # Phase-0 plumbing for the liberation phase ("conspiracy"): a scheduled,
  # trickled interactive invitation.
  #
  #   * events — the rollout window: invitations go out team-by-team between
  #     `liberation_starts_at` and `liberation_rollout_ends_at` (nil end =
  #     everyone at the start instant).
  #   * teams — per-team invitation + stance: when their invite went out, and
  #     how they answered (accepted/declined). Teams answer once.
  #   * notifications — first-ever interactive notification: the player's
  #     answer is recorded on the row itself alongside the team stance.
  def change do
    alter table(:events, prefix: "landgrab") do
      add(:liberation_starts_at, :utc_datetime)
      add(:liberation_rollout_ends_at, :utc_datetime)
    end

    alter table(:teams) do
      add(:liberation_invited_at, :utc_datetime)
      add(:liberation_response, :string)
      add(:liberation_responded_at, :utc_datetime)
    end

    alter table(:notifications, prefix: "landgrab") do
      add(:response, :string)
      add(:responded_at, :utc_datetime)
    end
  end
end
