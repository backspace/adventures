import DateTransform from 'gathering/transforms/ember-data-date';

export default class CreateDateTransform extends DateTransform {
  serialize(deserialized) {
    return super.serialize(deserialized || new Date());
  }
}
