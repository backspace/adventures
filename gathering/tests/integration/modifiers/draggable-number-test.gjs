import { on } from '@ember/modifier';
import { find, render, triggerEvent } from '@ember/test-helpers';
import draggableNumber from 'gathering/modifiers/draggable-number';
import { setupRenderingTest } from 'ember-qunit';
import { module, test } from 'qunit';

module('Integration | Modifier | draggable-number', function (hooks) {
  setupRenderingTest(hooks);

  test('it lets number fields be set by dragging', async function (assert) {
    let value = '10';

    function updateValue(e) {
      value = e.target.value;
    }

    await render(<template>
      <input
        value={{value}}
        min='0'
        max='1000'
        step='1'
        aria-label='test input'
        {{draggableNumber}}
        {{on 'change' updateValue}}
      />
    </template>);

    let input = find('input');

    // These are pretty imprecise but it at least shows that dragging changes the value

    await drag(input, -100);
    assert.strictEqual(value, '30');

    await drag(input, -200);
    assert.strictEqual(value, '70');
  });
});

async function drag(element, y) {
  await triggerEvent(element, 'mousedown', {
    clientY: 0,
  });
  await triggerEvent(document.body, 'mousemove', {
    clientY: y,
  });
  await triggerEvent(element, 'mouseup');
}
