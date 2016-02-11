import Ember from 'ember';
import computedStyle from 'ember-computed-style';

export default Ember.Component.extend({
  classNames: ['region'],
  classNameBindings: ['isHighlighted:highlighted'],

  style: computedStyle('top', 'left'),
  attributeBindings: ['style', 'draggable'],

  draggable: true,

  top: Ember.computed('region.y', function() {
    return {top: Math.max(this.get('region.y'), 0)};
  }),

  left: Ember.computed('region.x', function() {
    return {left: Math.max(this.get('region.x'), 0)};
  }),

  meetingIndex: Ember.computed('region.id', 'highlightedTeam.id', function() {
    const regionId = this.get('region.id');
    const highlightedTeam = this.get('highlightedTeam');

    if (highlightedTeam) {
      const meetingRegionIds = highlightedTeam.hasMany('meetings').value().rejectBy('isNew').map(meeting => meeting.belongsTo('destination').value()).map(destination => destination.belongsTo('region').value()).mapBy('id');
      const index = meetingRegionIds.indexOf(regionId);

      if (index > -1) {
        return index + 1;
      } else {
        return undefined;
      }
    } else {
      return undefined;
    }
  }),

  dragStart() {
    if (!this.get('draggable')) {
      return;
    }

    const offset = this.$().offset();
    const height = this.$().height();

    // Not adding the height causes the region to be off by its height?!
    this.set('originalPosition', {x: offset.left, y: height + offset.top});
  },

  dragEnd({originalEvent: {pageX, pageY}}) {
    if (!this.get('draggable')) {
      return;
    }

    const originalPosition = this.get('originalPosition');

    const x = this.get('region.x');
    const y = this.get('region.y');

    this.set('region.x', x + (pageX - originalPosition.x));
    this.set('region.y', y + (pageY - originalPosition.y));

    this.get('region').save();
  },

  mouseEnter() {
    // FIXME accomplish in a more idiomatic Ember fashion?
    const element = Ember.$(`#region-${this.get('region.id')}`)[0];

    if (element) {
      element.scrollIntoView();
    }
  }
});
