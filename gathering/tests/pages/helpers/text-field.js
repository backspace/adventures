import { fillable, value, text, hasClass } from 'ember-cli-page-object';

export default function textField(containerSelector, inputType = 'input') {
  return {
    scope: `${containerSelector} ${inputType ?? 'input'}`,
    value: value(),
    fill: fillable(),
    isInvalid: hasClass('border-red-500'),
    errors: text(`${containerSelector} [data-test-errors]`, {
      resetScope: true,
    }),
  };
}
