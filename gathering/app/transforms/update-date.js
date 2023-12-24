import DateTransform from 'gathering/transforms/ember-data-date';

export default class UpdateDateTransform extends DateTransform {
  serialize() {
    return super.serialize(new Date());
  }
}
