# TODO This seems ridiculous? Is this the standard way to cast database inputs?

defmodule Cr2016siteWeb.DowncasedString do
  use Ecto.Type
  def type, do: :string

  def cast(string) when is_bitstring(string) do
    {:ok, String.downcase(string)}
  end

  def cast(_), do: :error

  def load(string) when is_bitstring(string), do: {:ok, String.downcase(string)}

  def dump(string) when is_bitstring(string), do: {:ok, string}
  def dump(_), do: :error
end
