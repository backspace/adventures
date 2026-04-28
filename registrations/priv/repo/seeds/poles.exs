# Seed data for the poles adventure. Idempotent: re-running won't duplicate.
#
#   ADVENTURE=poles mix run priv/repo/seeds/poles.exs

import Ecto.Query, only: [from: 2]

alias Pow.Ecto.Schema.Password
alias Registrations.Poles
alias Registrations.Poles.Puzzlet
alias Registrations.Repo
alias RegistrationsWeb.Team
alias RegistrationsWeb.User

defmodule Seed do
  def upsert_team(name) do
    case Repo.get_by(Team, name: name) do
      nil -> Repo.insert!(%Team{name: name, risk_aversion: 1})
      team -> team
    end
  end

  def upsert_user(email, password, team) do
    case Repo.get_by(User, email: email) do
      nil ->
        Repo.insert!(%User{
          email: email,
          password_hash: Password.pbkdf2_hash(password),
          team_id: team.id,
          name: "Dev User"
        })

      user ->
        user
    end
  end

  def upsert_pole(attrs, puzzlets) do
    case Repo.get_by(Registrations.Poles.Pole, barcode: attrs.barcode) do
      nil ->
        {:ok, pole} = Poles.create_pole(attrs)

        Enum.each(puzzlets, fn p ->
          Repo.insert!(%Puzzlet{
            pole_id: pole.id,
            instructions: p.instructions,
            answer: p.answer,
            difficulty: p.difficulty,
            status: :validated
          })
        end)

        IO.puts("seeded pole #{attrs.barcode} with #{length(puzzlets)} puzzlets")
        pole

      pole ->
        IO.puts("pole #{attrs.barcode} already exists, skipping")
        pole
    end
  end
end

alpha = Seed.upsert_team("Alpha Wolves")
beta = Seed.upsert_team("Beta Bears")
Seed.upsert_user("dev@example.com", "Xenogenesis", alpha)
Seed.upsert_user("dev2@example.com", "Xenogenesis", beta)

# Coordinates clustered around downtown Winnipeg. Edit to fit your playing field.
poles = [
  %{
    pole: %{barcode: "POLE-001", label: "The Forks", latitude: 49.8889, longitude: -97.1303},
    puzzlets: [
      %{instructions: "Two rivers meet here. Name the one that flows in from the west.", answer: "Assiniboine", difficulty: 1},
      %{instructions: "Count the flags flying at the main entrance plaza.", answer: "5", difficulty: 3}
    ]
  },
  %{
    pole: %{barcode: "POLE-002", label: "Legislative Building", latitude: 49.8884, longitude: -97.1373},
    puzzlets: [
      %{instructions: "Name the gilded figure atop the dome.", answer: "Golden Boy", difficulty: 1},
      %{instructions: "What year was the Golden Boy placed on the dome?", answer: "1919", difficulty: 4}
    ]
  },
  %{
    pole: %{barcode: "POLE-003", label: "Portage and Main", latitude: 49.8951, longitude: -97.1384},
    puzzlets: [
      %{instructions: "How many corners does the intersection have?", answer: "4", difficulty: 1},
      %{instructions: "Which Burton Cummings song made this corner famous?", answer: "Stand Tall", difficulty: 6}
    ]
  },
  %{
    pole: %{barcode: "POLE-004", label: "Esplanade Riel", latitude: 49.8898, longitude: -97.1267},
    puzzlets: [
      %{instructions: "Which river does this pedestrian bridge cross?", answer: "Red", difficulty: 1},
      %{instructions: "What neighbourhood does the bridge connect to on the east bank?", answer: "St. Boniface", difficulty: 4}
    ]
  },
  %{
    pole: %{barcode: "POLE-005", label: "Canadian Museum for Human Rights", latitude: 49.8901, longitude: -97.1305},
    puzzlets: [
      %{instructions: "What year did the museum open?", answer: "2014", difficulty: 2},
      %{instructions: "Name the architect of the building.", answer: "Antoine Predock", difficulty: 5},
      %{instructions: "How many storeys tall is the Tower of Hope?", answer: "8", difficulty: 8}
    ]
  }
]

Enum.each(poles, fn entry -> Seed.upsert_pole(entry.pole, entry.puzzlets) end)

# A handful of unassigned puzzlets, to exercise the "discovered en masse" flow.
unassigned = [
  %{instructions: "What's at the top of the Bow tower?", answer: "wonderland", difficulty: 2},
  %{instructions: "How many cars on the C-Train at rush hour?", answer: "4", difficulty: 3}
]

existing_unassigned = Repo.aggregate(from(p in Puzzlet, where: is_nil(p.pole_id)), :count, :id)

if existing_unassigned == 0 do
  Enum.each(unassigned, fn p ->
    Repo.insert!(%Puzzlet{
      instructions: p.instructions,
      answer: p.answer,
      difficulty: p.difficulty,
      status: :draft
    })
  end)

  IO.puts("seeded #{length(unassigned)} unassigned puzzlets")
else
  IO.puts("unassigned puzzlets already present, skipping")
end

IO.puts("\nDone. Try: POST /powapi/session with dev@example.com / Xenogenesis")
