import PageObject from '../page-object';

const { attribute, clickable, collection, customHelper, text, visitable } = PageObject;

const propertyColourName = customHelper((selectorAndProperty) => {
  const [selector, property] = selectorAndProperty.split(/\s/);
  const propertyColour = $(selector).css(property);

  /* globals tinycolor */
  const colour = tinycolor(propertyColour);
  return colour.toName();
});

const propertyValue = customHelper((selectorAndProperty) => {
  const split = selectorAndProperty.split(/\s/);
  const property = split.pop();
  return $(split.join(' ')).css(property);
});

const selectText = customHelper((selector) => {
  const id = $(selector).val();
  return $(`${selector} option[value=${id}]`).text();
});

export default PageObject.create({
  visit: visitable('/scheduler'),

  regions: collection({
    itemScope: '.region',

    item: {
      name: text('.name'),
      notes: attribute('title'),

      destinations: collection({
        itemScope: '.destination',

        item: {
          description: text('.description'),
          qualities: attribute('title'),
          accessibility: text('.accessibility'),
          meetingCountBorderWidth: propertyValue('border-top-width'),

          click: clickable()
        }
      })
    }
  }),

  teams: collection({
    itemScope: '.team',

    item: {
      name: text('.name'),
      users: attribute('title'),
      count: text('.count'),
      riskAversionColour: propertyColourName('border-right-color'),

      click: clickable()
    }
  }),

  meeting: {
    scope: '.meeting-form',

    destination: selectText('.destination'),
    teamOne: selectText('.team:eq(0)'),
    teamTwo: selectText('.team:eq(1)'),

    teams: collection({
      itemScope: '.team'
    }),

    save: clickable('button.save'),
    reset: clickable('button.reset')
  }
});
