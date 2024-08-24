defmodule Registrations.Repo.Migrations.MoveFillInTheBlankAnswerToAnswers do
  @moduledoc false
  use Ecto.Migration

  def up do
    execute("""
    UPDATE waydowntown.incarnations
    SET answers = ARRAY[answer]
    WHERE concept = 'fill_in_the_blank' AND answer IS NOT NULL;
    """)

    alter table(:incarnations, prefix: "waydowntown") do
      remove(:answer)
    end
  end

  def down do
    alter table(:incarnations, prefix: "waydowntown") do
      add(:answer, :string)
    end

    execute("""
    UPDATE waydowntown.incarnations
    SET answer = answers[1]
    WHERE concept = 'fill_in_the_blank' AND array_length(answers, 1) > 0;
    """)
  end
end
