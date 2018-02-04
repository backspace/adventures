import { inject as service } from '@ember/service';
import { run } from '@ember/runloop';
import Route from '@ember/routing/route';

export default Route.extend({
  features: service(),
  settings: service(),

  beforeModel() {
    return this.get('settings').modelPromise().then(settings => {
      // FIXME why is this needed?
      run(() => {
        if (settings.get('destinationStatus')) {
          this.get('features').enable('destinationStatus');
        }
        return settings.save();
      });

    });
  }
});
