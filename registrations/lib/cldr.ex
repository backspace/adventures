defmodule Registrations.Cldr do
  use Cldr,
    locales: [:en],
    default_locale: "en",
    providers: [Cldr.List, Cldr.Number],
    precompile_number_formats: ["#,##0"]
end
