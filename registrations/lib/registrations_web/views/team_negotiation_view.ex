defmodule RegistrationsWeb.JSONAPI.TeamNegotiationView do
  def render("show.json", %{data: user, relationships: relationships, conn: _conn}) do
    included = build_included(user, relationships)

    %{
      data: %{
        id: user.id,
        type: "team-negotiations",
        attributes: %{
          team_emails: user.team_emails,
          proposed_team_name: user.proposed_team_name,
          risk_aversion: user.risk_aversion,
          empty: relationships[:empty?],
          only_mutuals: relationships[:only_mutuals?]
        },
        relationships: build_relationships(user, relationships)
      },
      included: included
    }
  end

  defp build_relationships(user, relationships) do
    base = %{
      mutuals: %{data: Enum.map(relationships[:mutuals], &member_ref/1)},
      proposers: %{data: Enum.map(relationships[:proposers], &member_ref/1)},
      proposees: %{data: Enum.map(relationships[:proposees], &proposee_ref/1)},
      invalids: %{data: Enum.map(relationships[:invalids], fn email -> %{type: "invalids", id: email} end)}
    }

    if user.team do
      Map.put(base, :team, %{data: %{type: "teams", id: user.team.id}})
    else
      base
    end
  end

  defp build_included(user, relationships) do
    team_included =
      if user.team do
        [build_team(user.team)]
      else
        []
      end

    mutuals_included = Enum.map(relationships[:mutuals], &build_member/1)
    proposers_included = Enum.map(relationships[:proposers], &build_member/1)
    proposees_included = Enum.map(relationships[:proposees], &build_proposee/1)
    invalids_included = Enum.map(relationships[:invalids], &build_invalid/1)

    team_included ++ mutuals_included ++ proposers_included ++ proposees_included ++ invalids_included
  end

  defp member_ref(user) do
    %{type: "team-members", id: user.id}
  end

  defp proposee_ref(proposee) do
    %{type: "proposees", id: proposee.email}
  end

  defp build_team(team) do
    %{
      id: team.id,
      type: "teams",
      attributes: %{
        name: team.name,
        risk_aversion: team.risk_aversion,
        notes: team.notes
      },
      relationships: %{
        members: %{data: Enum.map(team.users, &member_ref/1)}
      }
    }
  end

  defp build_member(user) do
    %{
      id: user.id,
      type: "team-members",
      attributes: %{
        email: user.email,
        name: user.name,
        risk_aversion: user.risk_aversion,
        proposed_team_name: user.proposed_team_name
      }
    }
  end

  defp build_proposee(proposee) do
    %{
      id: proposee.email,
      type: "proposees",
      attributes: %{
        email: proposee.email,
        invited: proposee.invited,
        registered: Map.get(proposee, :registered, false)
      }
    }
  end

  defp build_invalid(email) do
    %{
      id: email,
      type: "invalids",
      attributes: %{
        value: email
      }
    }
  end
end
