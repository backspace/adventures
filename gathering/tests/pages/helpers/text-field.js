import { fillable, value, text, hasClass } from 'ember-cli-page-object';

export default function textField(containerSelector) {
  return {
    scope: `${containerSelector} input`,
    value: value(),
    fill: fillable(),
    isInvalid: hasClass('border-red-500'),
    errors: text(`${containerSelector} [data-test-errors]`, {
      resetScope: true,
    }),
  };
}
