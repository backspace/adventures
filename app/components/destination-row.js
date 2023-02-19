import classic from 'ember-classic-decorator';
import { classNames, classNameBindings, tagName } from '@ember-decorators/component';
import { action, computed } from '@ember/object';
import { notEmpty } from '@ember/object/computed';
import Component from '@ember/component';

@classic
@tagName('tr')
@classNames('destination')
@classNameBindings('destination.isIncomplete:incomplete', 'hasMeetings:meetings')
export default class DestinationRow extends Component {
  @notEmpty('destination.meetings')
  hasMeetings;

  @computed('destination.status')
  get status() {
    const status = this.get('destination.status');

    if (status === 'available') {
      return '✓';
    } else if (status === 'unavailable') {
      return '✘';
    } else {
      return '?';
    }
  }

  @action
  toggleStatus() {
    const status = this.get('destination.status');
    let newStatus;

    if (status === 'available') {
      newStatus = 'unavailable';
    } else if (status === 'unavailable') {
      newStatus = undefined;
    } else {
      newStatus = 'available';
    }

    this.set('destination.status', newStatus);
    this.get('destination').save();
  }
}
