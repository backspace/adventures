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

  destinationRegions: collection(
    '[data-test-regions-destinations] [data-test-scheduler-column-region]',
    {
      name: text('> [data-test-name]'),
      accessibility: text('[data-test-region-accessibility]'),
      notes: attribute('title'),

      hover: triggerable('mouseenter'),
      exit: triggerable('mouseleave'),

      destinations: collection('[data-test-scheduler-destination]', {
        description: text('[data-test-description]'),
        qualities: attribute('title'),
        accessibility: text('[data-test-accessibility]'),

        meetingCountBorderWidth: propertyValue('border-top-width'),
        awesomenessBorderOpacity: propertyColourOpacity('border-left-color'),
        riskBorderOpacity: propertyColourOpacity('border-right-color'),

        isSelected: hasClass('selected'),
        isHighlighted: hasClass('highlighted'),

        click: clickable(),
      }),

      regions: collection('[data-test-scheduler-column-region]'),
    },
  ),

  waypointsContainer: {
    scope: '[data-test-waypoint-regions]',
  },

  waypointRegions: collection(
    '[data-test-waypoint-regions] [data-test-scheduler-column-region]',
    {
      name: text('> [data-test-name]'),
      accessibility: text('[data-test-region-accessibility]'),
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

      regions: collection('[data-test-scheduler-column-region]'),
    },
  ),

  teams: collection('[data-test-team]', {
    name: text('[data-test-name]'),
    usersAndNotes: attribute('title'),
    count: text('[data-test-count]'),
    riskAversionColour: propertyColourName('border-right-color'),

    averageAwesomeness: text('[data-test-average-awesomeness]'),
    averageRisk: text('[data-test-average-risk]'),

    isSelected: hasClass('selected'),
    isHighlighted: hasClass('highlighted'),
    isAhead: hasClass('ahead'),

    click: clickable('[data-test-name]'),
    hover: triggerable('mouseenter', '[data-test-name]'),

    meetings: collection('[data-test-meeting]', {
      click: clickable(),

      index: text('[data-test-index]'),
      offset: text('[data-test-offset]'),
    }),
  }),

  map: {
    scope: '[data-test-map]',

    regions: collection('[data-test-mappable-region]', {
      x: x(),
      y: y(),

      name: text('[data-test-name]'),

      meetingIndex: text('[data-test-meeting-index]'),
      waypointMeetingIndex: text('[data-test-waypoint-meeting-index]'),

      count: text('[data-test-count]'),

      isHighlighted: hasClass('highlighted'),
    }),
  },

  meeting: {
    scope: '[data-test-meeting-form]',

    destination: selectText('[data-test-destination]'),
    waypoint: selectText('[data-test-waypoint]'),

    index: value('[data-test-index]'),

    offset: {
      scope: '[data-test-offset-input]',
    },

    teams: collection('[data-test-team]', {
      value: selectText(),
    }),

    isForbidden: hasClass('forbidden'),
    saveIsHidden: isHidden('[data-test-save]'),

    save: clickable('[data-test-save]'),
    reset: clickable('[data-test-reset]'),
  },
});
