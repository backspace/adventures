import $ from 'jquery';
import { computed } from '@ember/object';
import Component from '@ember/component';
import { htmlSafe } from '@ember/template';

export default Component.extend({
  classNames: ['region'],
  classNameBindings: ['isHighlighted:highlighted'],

  attributeBindings: ['style', 'draggable'],

  draggable: true,

  style: computed('region.{x,y}', function() {
    return htmlSafe(
      `top: ${Math.max(this.get('region.y'), 0)}px;` +
      `left: ${Math.max(this.get('region.x'), 0)}px`
    );
  }),

  meetingIndex: computed('region.id', 'highlightedTeam.id', function() {
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

    const offset = $(this.element).offset();
    const height = $(this.element).height();

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

  click() {
    // FIXME accomplish in a more idiomatic Ember fashion?
    const element = $(`#region-${this.get('region.id')}`)[0];

    if (element) {
      element.scrollIntoView();
    }
  }
});
