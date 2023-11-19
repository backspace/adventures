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

      await triggerEvent(jqueryElement[0], 'mousedown', {
        clientX: position.left,
        clientY: position.top,
        offsetX: 0,
      });
      await triggerEvent(jqueryElement[0], 'mouseup', {
        clientX: position.left + x,
        clientY: position.top + y,
      });
    },
  }),

  setMap: setMap('input#map'),
});
