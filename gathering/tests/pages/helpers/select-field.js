import { fillIn } from '@ember/test-helpers';
import {
  collection,
  findElement,
  selectable,
  value,
  text,
  hasClass,
} from 'ember-cli-page-object';

const selectText = function (selector) {
  return {
    isDescriptor: true,

    get() {
      const selectElement = findElement(this, selector);
      const id = selectElement.val();

      if (id) {
        return selectElement.find(`option[value=${id}]`).text().trim();
      } else {
        return '';
      }
    },
  };
};

const fillSelectByText = function (selector) {
  return {
    isDescriptor: true,

    value(text) {
      const selectElement = findElement(this, selector);
      const id = selectElement.find(`option:contains('${text}')`).attr('value');
      return fillIn(selectElement[0], id);
    },
  };
};

export default function selectField(containerSelector) {
  return {
    scope: `${containerSelector} select`,
    value: value(),
    text: selectText(),
    fillByText: fillSelectByText(),
    select: selectable(),
    options: collection('option'),
    isInvalid: hasClass('border-red-500'),
    errors: text(`${containerSelector} [data-test-errors]`, {
      resetScope: true,
    }),
  };
}
