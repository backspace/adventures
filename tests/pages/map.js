import PageObject from '../page-object';

const { attribute, collection, customHelper, text } = PageObject;

import $ from 'jquery';

const x = customHelper(selector => parseInt($(selector).css('left')));
const y = customHelper(selector => parseInt($(selector).css('top')));

const dragBy = customHelper(selector => {
  return ((x, y) => {
    const position = $(selector).position();

    triggerEvent(selector, 'dragstart', {originalEvent: {pageX: position.left, pageY: position.top}});
    triggerEvent(selector, 'dragend', {originalEvent: {pageX: position.left + x, pageY: position.top + y}});
  });
});

const setMap = customHelper(selector => {
  return ((base64) => {
    const blob = new window.Blob([base64], {type: 'image/gif'});

    $(selector).trigger({
      type: 'change',
      target: {
        files: [blob]
      }
    });
  });
});

export default PageObject.create({
  imageSrc: attribute('src', 'img'),

  regions: collection({
    itemScope: '.region',

    item: {
      name: text('.name'),
      x: x(),
      y: y(),

      dragBy: dragBy()
    }
  }),

  setMap: setMap('input#map')
});
