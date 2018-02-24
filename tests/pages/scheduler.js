import PageObject, {
  attribute,
  clickable,
  collection,
  findElement,
  hasClass,
  isHidden,
  text,
  value,
  visitable
} from 'ember-cli-page-object';

const x = function(selector) {
  return {
    isDescriptor: true,

    get() {
      return parseInt(findElement(this, selector).css('left'));
    }
  }
}

const y = function(selector) {
  return {
    isDescriptor: true,

    get() {
      return parseInt(findElement(this, selector).css('top'));
    }
  };
}

const propertyColourName = function(property) {
  return {
    isDescriptor: true,

    get() {
      const propertyColour = findElement(this).css(property);

      /* globals tinycolor */
      const colour = tinycolor(propertyColour);
      return colour.toName();
    }
  };
}

const propertyColourOpacity = function(property) {
  return {
    isDescriptor: true,

    get() {
      const propertyColour = findElement(this).css(property);

      /* globals tinycolor */
      const colour = tinycolor(propertyColour);
      return colour.getAlpha();
    }
  };
}

const propertyValue = function(property) {
  return {
    isDescriptor: true,

    get() {
      return findElement(this).css(property);
    }
  }
}

const selectText = function(selector) {
  return {
    isDescriptor: true,

    get() {
      const selectElement = findElement(this, selector);
      const id = selectElement.val();

      if (id) {
        return selectElement.find(`option[value=${id}]`).text();
      } else {
        return '';
      }
    }
  };
}

const hoverable = function(selector) {
  return {
    isDescriptor: true,

    value() {
      findElement(this, selector).trigger({type: 'mouseenter'});
    }
  };
}

const exitable = function(selector) {
  return {
    isDescriptor: true,

    value() {
      findElement(this, selector).trigger({type: 'mouseleave'});
    }
  };
}

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
      usersAndNotes: attribute('title'),
      count: text('.count'),
      riskAversionColour: propertyColourName('border-right-color'),

      averageAwesomeness: text('.average-awesomeness'),
      averageRisk: text('.average-risk'),

      isSelected: hasClass('selected'),
      isHighlighted: hasClass('highlighted'),
      isAhead: hasClass('ahead'),

      click: clickable('.name'),
      hover: hoverable(),

      meetings: collection({
        itemScope: '.meeting',

        item: {
          click: clickable(),

          index: text('.index'),
          offset: text('.offset')
        }
      })
    }
  }),

  map: {
    scope: '.map',

    regions: collection({
      itemScope: '.region',

      item: {
        x: x(),
        y: y(),

        meetingIndex: text('.meeting-index'),

        count: text('.count'),

        isHighlighted: hasClass('highlighted')
      }
    })
  },

  meeting: {
    scope: '.meeting-form',

    destination: selectText('.destination'),
    index: value('.index'),

    teams: collection({
      itemScope: '.team',

      item: {
        value: selectText()
      }
    }),

    isForbidden: hasClass('forbidden'),
    saveIsHidden: isHidden('button.save'),

    save: clickable('button.save'),
    reset: clickable('button.reset')
  }
});
