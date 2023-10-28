import PageObject, {
  clickable,
  collection,
  fillable,
  findElement,
  hasClass,
  selectable,
  text,
  value,
  visitable,
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
      findElement(this, selector).val(id).trigger('change');
    },
  };
};

export default PageObject.create({
  visit: visitable('/destinations'),

  headerRegion: {
    scope: 'th.region',
    click: clickable(),
  },

  headerAwesomeness: {
    scope: 'th.awesomeness',
    click: clickable(),
  },

  destinations: collection('.destination', {
    description: text('.description'),
    answer: text('.answer'),
    awesomeness: text('.awesomeness'),
    risk: text('.risk'),
    mask: text('.mask'),

    isIncomplete: hasClass('incomplete'),
    hasMeetings: hasClass('meetings'),

    region: text('.region'),

    status: {
      scope: '.status',
      value: text(),
      click: clickable(),
    },

    edit: clickable('.edit'),
  }),

  new: clickable('.destinations.new'),

  descriptionField: {
    scope: 'textarea.description',
    value: value(),
    fill: fillable(),
  },

  accessibilityField: {
    scope: 'textarea.accessibility',
    value: value(),
    fill: fillable(),
  },

  awesomenessField: {
    scope: 'input.awesomeness',
    value: value(),
    fill: fillable(),
  },

  riskField: {
    scope: 'input.risk',
    value: value(),
    fill: fillable(),
  },

  answerField: {
    scope: 'input.answer',
    value: value(),
    fill: fillable(),
  },

  maskField: {
    scope: 'input.mask',
    value: value(),
    fill: fillable(),
  },

  suggestedMaskButton: {
    scope: 'button.suggested-mask',
    label: text(),
    click: clickable(),
  },

  creditField: {
    scope: '[data-test-credit]',
    value: value(),
    fill: fillable(),
  },

  regionField: {
    scope: 'select.region',
    value: value(),
    text: selectText(),
    fillByText: fillSelectByText(),
    select: selectable(),
    options: collection('option'),
  },

  statusFieldset: {
    scope: 'fieldset.status',

    availableOption: {
      scope: 'input[value=available]',
      click: clickable(),
    },
  },

  errors: {
    scope: '[data-test-errors]',
  },

  save: clickable('.save'),
  cancel: clickable('.cancel'),
  delete: clickable('.delete'),
});
