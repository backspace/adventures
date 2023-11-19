import { camelize } from '@ember/string';

export default async function withSetting(owner, setting, value = true) {
  const store = owner.lookup('service:store');

  const record =
    store.peekRecord('settings', 'settings') ||
    store.createRecord('settings', {
      id: 'settings',
    });

  record.set(camelize(setting), value);
  return record.save();
}

export async function withoutSetting(owner, setting) {
  return withSetting(owner, setting, false);
}
