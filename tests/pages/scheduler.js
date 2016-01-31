import PageObject from '../page-object';

const { attribute, clickable, collection, customHelper, hasClass, text, visitable } = PageObject;

const x = customHelper(selector => parseInt($(selector).css('left')));
const y = customHelper(selector => parseInt($(selector).css('top')));

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

const hoverable = customHelper(selector => {
  triggerEvent(selector, 'mouseenter');
});

const exitable = customHelper(selector => {
  triggerEvent(selector, 'mouseleave');
});

export default PageObject.create({
  visit: visitable('/scheduler'),

  regions: collection({
    itemScope: 'li.region',

    item: {
      name: text('.name'),
      notes: attribute('title'),

      hover: hoverable(),
      exit: exitable(),

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

  map: {
    scope: '.map',

    regions: collection({
      itemScope: '.region',

      item: {
        x: x(),
        y: y(),

        isHighlighted: hasClass('highlighted')
      }
    })
  },

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
