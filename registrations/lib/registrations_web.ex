defmodule RegistrationsWeb do
  @moduledoc """
  A module that keeps using definitions for controllers,
  views and so on.

  This can be used in your application as:

      use RegistrationsWeb, :controller
      use RegistrationsWeb, :view

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
      use Phoenix.Controller, namespace: RegistrationsWeb

      alias Registrations.Repo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]

      alias RegistrationsWeb.Router.Helpers, as: Routes

      import RegistrationsWeb.Pow.ControllerHelper
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/registrations_web/templates",
        namespace: RegistrationsWeb

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_csrf_token: 0, get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import RegistrationsWeb.Session, only: [current_user: 1, logged_in?: 1, admin?: 1]

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

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def mailer_view do
    quote do
      use Phoenix.View,
        root: "lib/registrations_web/templates",
        namespace: RegistrationsWeb

      use Phoenix.HTML
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

      alias Registrations.Repo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import LiveView and .heex helpers (live_render, live_patch, <.form>, etc)
      import Phoenix.LiveView.Helpers

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import RegistrationsWeb.ErrorHelpers
      import RegistrationsWeb.SharedHelpers
      import RegistrationsWeb.Gettext
      alias RegistrationsWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
