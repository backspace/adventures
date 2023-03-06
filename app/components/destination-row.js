import Component from '@glimmer/component';
import { action } from '@ember/object';

export default class DestinationRow extends Component {
  get hasMeetings() {
    return this.args.destination.meetings.length;
  }

  get status() {
    const status = this.args.destination.status;

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
    const status = this.args.destination.status;
    let newStatus;

    if (status === 'available') {
      newStatus = 'unavailable';
    } else if (status === 'unavailable') {
      newStatus = undefined;
    } else {
      newStatus = 'available';
    }

    this.args.destination.status = newStatus;
    this.args.destination.save();
  }
}
