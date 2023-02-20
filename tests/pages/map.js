import { triggerEvent } from '@ember/test-helpers';
import PageObject, {
  attribute,
  collection,
  findElement,
  text,
} from 'ember-cli-page-object';

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

const setMap = function (selector) {
  return {
    isDescriptor: true,

    value(base64) {
      const blob = new window.Blob([base64], { type: 'image/gif' });

      findElement(this, selector).trigger({
        type: 'change',
        target: {
          files: [blob],
        },
      });
    },
  };
};

export default PageObject.create({
  imageSrc: attribute('src', 'img'),

  regions: collection('.region', {
    name: text('.name'),
    x: x(),
    y: y(),

    async dragBy(x, y) {
      const jqueryElement = findElement(this, '.name');
      const position = jqueryElement.position();

      await triggerEvent(jqueryElement[0], 'dragstart', {
        pageX: position.left,
        pageY: position.top,
      });
      await triggerEvent(jqueryElement[0], 'dragend', {
        pageX: position.left + x,
        pageY: position.top + y,
      });
    },
  }),

  setMap: setMap('input#map'),
});
