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

  test "qr_url? matches explicit http(s) URLs and nothing else" do
    assert AnswerKeyView.qr_url?("https://example.com/claim/42")
    assert AnswerKeyView.qr_url?("HTTP://EXAMPLE.COM")
    # A bare domain isn't obviously a QR — stay strict.
    refute AnswerKeyView.qr_url?("example.com")
    refute AnswerKeyView.qr_url?("0245844")
    refute AnswerKeyView.qr_url?(nil)
  end

  test "answer_code_svg renders a QR (not a barcode) for URL-shaped answers" do
    {:safe, svg} = AnswerKeyView.answer_code_svg("https://example.com/claim/42")
    assert svg =~ "<svg"
    refute svg =~ "<?xml"
    # EQRCode's SVG carries the xml-events namespace; Barlix's does not.
    assert svg =~ "xml-events"
  end

  test "answer_code_svg falls back to a Code 128 barcode for non-URL answers" do
    {:safe, svg} = AnswerKeyView.answer_code_svg("0245844", height: 40)
    assert svg =~ "<svg"
    refute svg =~ "xml-events"
  end
end
