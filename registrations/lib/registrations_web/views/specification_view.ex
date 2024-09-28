defmodule RegistrationsWeb.SpecificationView do
  use JSONAPI.View, type: "specifications"

  alias RegistrationsWeb.Router.Helpers, as: Routes
  alias RegistrationsWeb.SpecificationView

  def fields do
    [:concept, :start_description, :duration, :placed, :task_description]
  end

  def task_description(specification, conn) do
    if conn.request_path == Routes.my_specifications_path(conn, :mine) do
      specification.task_description
    end
  end

  def placed(specification, _conn) do
    Registrations.Waydowntown.concept_is_placed(specification.concept)
  end

  def render("index.json", %{specifications: specifications, conn: conn, params: params}) do
    SpecificationView.index(specifications, conn, params)
  end

  def render("show.json", %{specification: specification, conn: conn, params: params}) do
    SpecificationView.show(specification, conn, params)
  end

  def relationships do
    [
      region: {RegistrationsWeb.RegionView, :include},
      answers: {RegistrationsWeb.AnswerView, :include}
    ]
  end
end
