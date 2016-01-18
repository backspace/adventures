import Ember from 'ember';

export default Ember.Controller.extend({
  actions: {
    save() {
      const {data: teams} = JSON.parse(this.get('teamsJSON'));

      Ember.RSVP.all(this.get('model').map(model => {
        model.deleteRecord();
        return model.save();
      })).then(() => {
        const teamRecords = teams.map(({attributes}) => {
          const teamRecord = this.store.createRecord('team');
          teamRecord.setProperties(attributes);

          return teamRecord.save();
        });

        return Ember.RSVP.all(teamRecords);
      });
    }
  }
});
