import { camelize } from '@ember/string';

export default async function (owner, setting) {
  const store = owner.lookup('service:store');

  const object = {
    id: 'settings',
  };

  object[camelize(setting)] = true;

  const settings = store.createRecord('settings', object);
  return settings.save();
}
