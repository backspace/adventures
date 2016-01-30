import PageObject from '../page-object';

const { attribute, collection, customHelper, text, visitable } = PageObject;

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
          meetingCountBorderWidth: propertyValue('border-top-width')
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
      riskAversionColour: propertyColourName('border-right-color')
    }
  })
});
