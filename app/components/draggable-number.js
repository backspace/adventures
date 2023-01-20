import Component from '@ember/component';

export default Component.extend({
  didInsertElement() {
    this._super();

    // FIXME restore…? but this would be a modifier now ya
    // $(this.element).find('input').draggableNumber();
  }
});
