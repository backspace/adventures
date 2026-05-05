# Seed data for the poles adventure. Idempotent: re-running won't duplicate.
#
#   ADVENTURE=poles mix run priv/repo/seeds/poles.exs

import Ecto.Query, only: [from: 2]

alias Pow.Ecto.Schema.Password
alias Registrations.Accounts
alias Registrations.Poles
alias Registrations.Poles.Pole
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

  def ensure_role(user, role) do
    if Accounts.has_role?(user, role) do
      :ok
    else
      {:ok, _} = Accounts.assign_role(user.id, role)
      IO.puts("assigned '#{role}' to #{user.email}")
      :ok
    end
  end

  def upsert_draft_pole(attrs, creator) do
    case Repo.get_by(Pole, barcode: attrs.barcode) do
      nil ->
        attrs =
          attrs
          |> Map.put(:status, :draft)
          |> Map.put(:creator_id, creator.id)

        {:ok, pole} = Poles.create_pole(attrs)
        IO.puts("seeded draft pole #{attrs.barcode} (#{creator.email})")
        pole

      pole ->
        IO.puts("draft pole #{attrs.barcode} already exists, skipping")
        pole
    end
  end

  def upsert_draft_puzzlet(attrs, creator) do
    existing =
      Repo.one(
        from(p in Puzzlet,
          where: p.creator_id == ^creator.id and p.instructions == ^attrs.instructions,
          limit: 1
        )
      )

    case existing do
      nil ->
        attrs =
          attrs
          |> Map.put(:status, :draft)
          |> Map.put(:creator_id, creator.id)

        {:ok, _} = Poles.create_puzzlet(attrs)
        IO.puts("seeded draft puzzlet for #{creator.email}: #{String.slice(attrs.instructions, 0, 40)}…")

      _ ->
        IO.puts("draft puzzlet for #{creator.email} already exists, skipping")
    end
  end
end

alpha = Seed.upsert_team("Alpha Wolves")
beta = Seed.upsert_team("Beta Bears")
dev1 = Seed.upsert_user("dev@example.com", "Xenogenesis", alpha)
dev2 = Seed.upsert_user("dev2@example.com", "Xenogenesis", beta)

Seed.ensure_role(dev1, "author")
Seed.ensure_role(dev2, "author")

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

# Draft poles authored by the dev users — for exercising the supervision
# workflow (assign → validate → accept). All in :draft status, awaiting review.
draft_poles_dev1 = [
  %{
    barcode: "DRAFT-D1-001",
    label: "Manitoba Hydro Place",
    latitude: 49.8911,
    longitude: -97.1409,
    notes: "Pole near the south entrance, tricky GPS in the urban canyon.",
    accuracy_m: 14.0
  },
  %{
    barcode: "DRAFT-D1-002",
    label: "Old Market Square",
    latitude: 49.8989,
    longitude: -97.1394,
    notes: "By the bandshell; flexible timing for puzzlets here.",
    accuracy_m: 6.5
  }
]

draft_poles_dev2 = [
  %{
    barcode: "DRAFT-D2-001",
    label: "Millennium Library",
    latitude: 49.8930,
    longitude: -97.1413,
    notes: "Main entrance, well-lit at night.",
    accuracy_m: 4.2
  },
  %{
    barcode: "DRAFT-D2-002",
    label: "Winnipeg Art Gallery",
    latitude: 49.8881,
    longitude: -97.1437,
    notes: "By the Inuit Art Centre side, sometimes blocked by events.",
    accuracy_m: 9.8
  }
]

Enum.each(draft_poles_dev1, &Seed.upsert_draft_pole(&1, dev1))
Enum.each(draft_poles_dev2, &Seed.upsert_draft_pole(&1, dev2))

# Draft puzzlets (unassigned to a pole) — admin will pair them later. Locations
# are where the author was when they wrote the question, not where they belong.
draft_puzzlets_dev1 = [
  %{
    instructions: "What four-letter word is etched above the main library doors?",
    answer: "READ",
    difficulty: 2,
    latitude: 49.8930,
    longitude: -97.1413
  },
  %{
    instructions: "How many bronze plaques line the entrance to the legislative grounds?",
    answer: "6",
    difficulty: 5,
    latitude: 49.8884,
    longitude: -97.1373
  }
]

draft_puzzlets_dev2 = [
  %{
    instructions: "Name the sculpture by the river at The Forks (the tall, twisted one).",
    answer: "Path of Time",
    difficulty: 6,
    latitude: 49.8889,
    longitude: -97.1303
  },
  %{
    instructions: "What's the visible street number above the Exchange District café entrance?",
    answer: "108",
    difficulty: 3,
    latitude: 49.8989,
    longitude: -97.1394
  }
]

Enum.each(draft_puzzlets_dev1, &Seed.upsert_draft_puzzlet(&1, dev1))
Enum.each(draft_puzzlets_dev2, &Seed.upsert_draft_puzzlet(&1, dev2))

IO.puts("\nDone. Try: POST /powapi/session with dev@example.com / Xenogenesis")
