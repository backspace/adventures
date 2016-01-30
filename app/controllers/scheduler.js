import Ember from 'ember';

export default Ember.Controller.extend({
  actions: {
    selectDestination(destination) {
      if (!this.get('meeting')) {
        this.set('meeting', this.store.createRecord('meeting'));
      }

      this.set('meeting.destination', destination);
    },

    selectTeam(team) {
      if (!this.get('meeting')) {
        this.set('meeting', this.store.createRecord('meeting'));
      }

      this.get('meeting.teams').pushObject(team);
    }
  }
});
