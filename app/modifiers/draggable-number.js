import { modifier } from 'ember-modifier';

export default modifier(function draggableNumber(element) {
  let divisor = 5.0;
  let fraction = 1 / parseFloat(element.getAttribute('step'));
  let max = parseFloat(element.getAttribute('max')) || Number.MAX_VALUE;
  let min = parseFloat(element.getAttribute('min'));

  let startValue = void 0;
  let startY = void 0;

  let bodyStartListener = (e) => {
    let y = getY(e);
    let dy = y - startY;
    let rounded = Math.round(dy / divisor) / fraction;

    element.value = Math.min(Math.max(min, startValue - rounded), max);
  };

  let bodyStopListener = () => {
    document.body.removeEventListener('mousemove', bodyStartListener);
    document.body.removeEventListener('touchmove', bodyStartListener);
    document.body.removeEventListener('mouseup', bodyStopListener);
    document.body.removeEventListener('touchend', bodyStopListener);
  };

  let elementStartListener = (e) => {
    let y = getY(e);
    let value = element.value;

    startValue = isNaN(value) || value === '' ? 0 : parseFloat(element.value);
    startY = y;

    document.body.addEventListener('mousemove', bodyStartListener);
    document.body.addEventListener('touchmove', bodyStartListener);
    document.body.addEventListener('mouseup', bodyStopListener);
    document.body.addEventListener('touchend', bodyStopListener);
  };

  element.addEventListener('mousedown', elementStartListener);
  element.addEventListener('touchstart', elementStartListener);

  return () => {
    element.removeEventListener('mousedown', elementStartListener);
    element.removeEventListener('touchstart', elementStartListener);
  };
});

function getY(event) {
  if (event.touches && event.touches[0]) {
    return event.touches[0].pageY;
  } else {
    return event.pageY;
  }
}
