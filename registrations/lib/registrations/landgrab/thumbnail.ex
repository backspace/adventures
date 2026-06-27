defmodule Registrations.Landgrab.Thumbnail do
  @moduledoc """
  Resize attachment image bytes into a small JPEG thumbnail using libvips.
  """

  alias Vix.Vips.Image
  alias Vix.Vips.Operation

  @max_dimension 240
  @quality 80

  @doc """
  Returns `{:ok, jpeg_bytes}` for a thumbnail no larger than #{@max_dimension}px
  on either side, or `{:error, reason}` if the input can't be decoded.
  """
  def from_bytes(bytes) when is_binary(bytes) do
    with {:ok, image} <- Image.new_from_buffer(bytes),
         scale = scale_for(image),
         {:ok, resized} <- Operation.resize(image, scale) do
      Image.write_to_buffer(resized, ".jpg[Q=#{@quality}]")
    end
  end

  defp scale_for(image) do
    width = Image.width(image)
    height = Image.height(image)
    longest = max(width, height)

    if longest <= @max_dimension do
      1.0
    else
      @max_dimension / longest
    end
  end
end
