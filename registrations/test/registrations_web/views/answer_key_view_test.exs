defmodule RegistrationsWeb.AnswerKeyViewTest do
  use ExUnit.Case, async: true

  alias RegistrationsWeb.AnswerKeyView

  test "barcode_svg renders an inline SVG without an XML prolog" do
    {:safe, svg} = AnswerKeyView.barcode_svg("0245844")
    assert svg =~ "<svg"
    refute svg =~ "<?xml"
  end

  test "barcode_svg accepts a height option" do
    {:safe, svg} = AnswerKeyView.barcode_svg("0245844", height: 40)
    assert svg =~ "40"
  end

  test "barcode_svg returns nil for values Code 128 cannot encode" do
    assert AnswerKeyView.barcode_svg("pôle") == nil
  end
end
