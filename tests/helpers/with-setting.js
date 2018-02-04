import { registerAsyncHelper } from '@ember/test';
import { camelize } from '@ember/string';

export default registerAsyncHelper('withSetting', function(app, setting) {
  const store = app.__container__.lookup('service:store');

  const object = {
    id: 'settings'
  };

  object[camelize(setting)] = true;

  const settings = store.createRecord('settings', object);
  settings.save();

  return wait();
});
