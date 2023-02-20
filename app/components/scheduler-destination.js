import Component from '@ember/component';
import { computed } from '@ember/object';
import { htmlSafe } from '@ember/template';

export default Component.extend({
  style: computed(
    'destination.{meetings.length,awesomeness,risk}',
    function () {
      return htmlSafe(
        `border-top-width: ${this.get('destination.meetings.length') * 2}px;` +
          `border-left-color: rgba(0, 0, 255, ${
            this.get('destination.awesomeness') / 10
          });` +
          `border-right-color: rgba(255, 0, 0, ${
            this.get('destination.risk') / 10
          });`
      );
    }
  ),

  actions: {
    select() {
      this.select(this.destination);
    },
  },
});
