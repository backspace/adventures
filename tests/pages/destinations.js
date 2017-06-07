import PageObject from '../page-object';

const { clickable, collection, customHelper, fillable, hasClass, selectable, text, value, visitable } = PageObject;

const selectText = customHelper((selector) => {
  const id = $(selector).val();
  return $(`${selector} option[value=${id}]`).text();
});

const fillSelectByText = customHelper((selector) => {
  return (text) => {
    const id = $(`${selector} option:contains('${text}')`).attr('value');
    $(selector).val(id).trigger('change');
  };
});

export default PageObject.create({
  visit: visitable('/destinations'),

  headerRegion: {
    scope: 'th.region',
    click: clickable()
  },

  headerAwesomeness: {
    scope: 'th.awesomeness',
    click: clickable()
  },

  destinations: collection({
    itemScope: '.destination',

    item: {
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
        click: clickable()
      },

      edit: clickable('.edit')
    }
  }),

  new: clickable('.destinations.new'),

  descriptionField: {
    scope: 'textarea.description',
    value: value(),
    fill: fillable()
  },

  accessibilityField: {
    scope: 'textarea.accessibility',
    value: value(),
    fill: fillable()
  },

  awesomenessField: {
    scope: 'input.awesomeness',
    value: value(),
    fill: fillable()
  },

  riskField: {
    scope: 'input.risk',
    value: value(),
    fill: fillable()
  },

  answerField: {
    scope: 'input.answer',
    value: value(),
    fill: fillable()
  },

  maskField: {
    scope: 'input.mask',
    value: value(),
    fill: fillable()
  },

  suggestedMaskButton: {
    scope: 'button.suggested-mask',
    label: text(),
    click: clickable()
  },

  regionField: {
    scope: 'select.region',
    value: value(),
    text: selectText(),
    fillByText: fillSelectByText(),
    select: selectable()
  },

  statusFieldset: {
    scope: 'fieldset.status',

    availableOption: {
      scope: 'input[value=available]',
      click: clickable()
    }
  },

  save: clickable('.save'),
  cancel: clickable('.cancel'),
  delete: clickable('.delete')
});
