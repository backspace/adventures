import PageObject from '../page-object';

const { attribute, clickable, collection, customHelper, hasClass, text, visitable } = PageObject;

const propertyColourName = customHelper((selectorAndProperty) => {
  const [selector, property] = selectorAndProperty.split(/\s/);
  const propertyColour = $(selector).css(property);

  /* globals tinycolor */
  const colour = tinycolor(propertyColour);
  return colour.toName();
});

const propertyColourOpacity = customHelper((selectorAndProperty) => {
  const split = selectorAndProperty.split(/\s/);
  const property = split.pop();

  const propertyColour = $(split.join(' ')).css(property);

  /* globals tinycolor */
  const colour = tinycolor(propertyColour);
  return colour.getAlpha();
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
          awesomenessBorderOpacity: propertyColourOpacity('border-left-color'),
          riskBorderOpacity: propertyColourOpacity('border-right-color'),

          isSelected: hasClass('selected'),

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

      isSelected: hasClass('selected'),

      click: clickable()
    }
  }),

  meeting: {
    scope: '.meeting-form',

    destination: selectText('.destination'),

    teams: collection({
      itemScope: '.team',

      item: {
        value: selectText()
      }
    }),

    save: clickable('button.save'),
    reset: clickable('button.reset')
  }
});
