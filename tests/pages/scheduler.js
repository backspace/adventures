import PageObject, {
  attribute,
  clickable,
  collection,
  findElement,
  hasClass,
  isHidden,
  text,
  triggerable,
  value,
  visitable,
} from 'ember-cli-page-object';
import tinycolor from 'tinycolor2';

const x = function (selector) {
  return {
    isDescriptor: true,

    get() {
      return parseInt(findElement(this, selector).css('left'));
    },
  };
};

const y = function (selector) {
  return {
    isDescriptor: true,

    get() {
      return parseInt(findElement(this, selector).css('top'));
    },
  };
};

const propertyColourName = function (property) {
  return {
    isDescriptor: true,

    get() {
      const propertyColour = findElement(this).css(property);

      const colour = tinycolor(propertyColour);
      return colour.toName();
    },
  };
};

const propertyColourOpacity = function (property) {
  return {
    isDescriptor: true,

    get() {
      const propertyColour = findElement(this).css(property);

      const colour = tinycolor(propertyColour);
      return colour.getAlpha();
    },
  };
};

const propertyValue = function (property) {
  return {
    isDescriptor: true,

    get() {
      return findElement(this).css(property);
    },
  };
};

const selectText = function (selector) {
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
    },
  };
};

export default PageObject.create({
  visit: visitable('/scheduler'),

  regions: collection('[data-test-regions-destinations] li.region', {
    name: text('.name'),
    accessibility: text('[data-test-accessibility]'),
    notes: attribute('title'),

    hover: triggerable('mouseenter'),
    exit: triggerable('mouseleave'),

    destinations: collection('.destination', {
      description: text('.description'),
      qualities: attribute('title'),
      accessibility: text('.accessibility'),

      meetingCountBorderWidth: propertyValue('border-top-width'),
      awesomenessBorderOpacity: propertyColourOpacity('border-left-color'),
      riskBorderOpacity: propertyColourOpacity('border-right-color'),

      isSelected: hasClass('selected'),
      isHighlighted: hasClass('highlighted'),

      click: clickable(),
    }),
  }),

  waypointsContainer: {
    scope: '[data-test-waypoint-regions]',
  },

  waypointRegions: collection('[data-test-waypoint-regions] li.region', {
    name: text('.name'),
    accessibility: text('[data-test-accessibility]'),
    notes: attribute('title'),

    hover: triggerable('mouseenter'),
    exit: triggerable('mouseleave'),

    waypoints: collection('[data-test-waypoint]', {
      name: text('[data-test-name]'),

      meetingCountBorderWidth: propertyValue('border-top-width'),

      isSelected: hasClass('selected'),
      isHighlighted: hasClass('highlighted'),

      click: clickable(),
    }),
  }),

  teams: collection('.team', {
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
    hover: triggerable('mouseenter', '.name'),

    meetings: collection('.meeting', {
      click: clickable(),

      index: text('.index'),
      offset: text('.offset'),
    }),
  }),

  map: {
    scope: '.map',

    regions: collection('.region', {
      x: x(),
      y: y(),

      meetingIndex: text('.meeting-index'),
      waypointMeetingIndex: text('[data-test-waypoint-meeting-index]'),

      count: text('.count'),

      isHighlighted: hasClass('highlighted'),
    }),
  },

  meeting: {
    scope: '.meeting-form',

    destination: selectText('.destination'),
    waypoint: selectText('.waypoint'),

    index: value('.index'),

    offset: {
      scope: '[data-test-offset-input]',
    },

    teams: collection('.team', {
      value: selectText(),
    }),

    isForbidden: hasClass('forbidden'),
    saveIsHidden: isHidden('button.save'),

    save: clickable('button.save'),
    reset: clickable('button.reset'),
  },
});
