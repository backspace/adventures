defmodule AdventureRegistrationsWeb do
  @moduledoc """
  A module that keeps using definitions for controllers,
  views and so on.

  This can be used in your application as:

      use AdventureRegistrationsWeb, :controller
      use AdventureRegistrationsWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below.
  """

  def model do
    quote do
      use Ecto.Schema

      import Ecto
      import Ecto.Changeset
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, namespace: AdventureRegistrationsWeb

      alias AdventureRegistrations.Repo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]

      alias AdventureRegistrationsWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/adventure_registrations_web/templates",
        namespace: AdventureRegistrationsWeb

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_csrf_token: 0, get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      alias AdventureRegistrationsWeb.Router.Helpers, as: Routes
      import AdventureRegistrationsWeb.ErrorHelpers
      import AdventureRegistrationsWeb.SharedHelpers
      import AdventureRegistrationsWeb.Gettext

      import AdventureRegistrationsWeb.Session, only: [current_user: 1, logged_in?: 1, admin?: 1]

      # Adapter from http://stackoverflow.com/a/31577025/760389
      def active_class(conn, path) do
        current_path = Path.join(["/" | conn.path_info])

        if (String.starts_with?(current_path, path) && path != "/") || current_path == path do
          "active"
        else
          nil
        end
      end

      def active_link(text, conn, path, opts) do
        class =
          [opts[:class], active_class(conn, path)]
          |> Enum.filter(& &1)
          |> Enum.join(" ")

        opts =
          opts
          |> Keyword.put(:class, class)
          |> Keyword.put(:to, path)

        link(text, opts)
      end
    end
  end

  def router do
    quote do
      use Phoenix.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel

      alias AdventureRegistrations.Repo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
