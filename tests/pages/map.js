import PageObject, {
  attribute,
  collection,
  findElement,
  text,
  triggerEvent,
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

const dragBy = function(selector) {
  return {
    isDescriptor: true,

    // TODO seems weird that this is called value when it’s performing an action?
    value(x, y) {
      const position = findElement(this, selector).position();

      triggerEvent(selector, 'dragstart', {originalEvent: {pageX: position.left, pageY: position.top}});
      triggerEvent(selector, 'dragend', {originalEvent: {pageX: position.left + x, pageY: position.top + y}});
    }
  };
}

const setMap = function(selector) {
  return {
    isDescriptor: true,

    value(base64) {
      const blob = new window.Blob([base64], {type: 'image/gif'});

      findElement(this, selector).trigger({
        type: 'change',
        target: {
          files: [blob]
        }
      });
    }
  };
};

export default PageObject.create({
  imageSrc: attribute('src', 'img'),

  regions: collection('.region', {
    name: text('.name'),
    x: x(),
    y: y(),

    dragBy: dragBy()
  }),

  setMap: setMap('input#map')
});
