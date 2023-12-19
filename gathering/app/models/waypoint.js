import { inject as service } from '@ember/service';
import { belongsTo, hasMany, attr } from '@ember-data/model';
import Yup from 'adventure-gathering/utils/yup';
import Model from 'ember-pouch/model';
import { string } from 'yup';

export default class Waypoint extends Model {
  @service puzzles;

  schemas = new Yup(this, {
    region: string().required(),
    call: string().required(),
    name: string().required(),
    excerpt: string()
      .required()
      .test(
        'is-valid',
        (d) => ({ key: 'invalid', path: d.path, values: {} }),
        (value) => this.puzzles.implementation.excerptIsValid(value),
      ),
    dimensions: string()
      .required()
      .test(
        'is-valid',
        (d) => ({ key: 'invalid', path: d.path, values: {} }),
        (value) => this.puzzles.implementation.dimensionsIsValid(value),
      ),
    outline: string()
      .required()
      .test(
        'is-valid',
        (d) => ({ key: 'invalid', path: d.path, values: {} }),
        (value) => this.puzzles.implementation.outlineIsValid(value),
      ),
    page: string().required(),
  });

  get validations() {
    return this.schemas.validate();
  }

  @belongsTo('region', { inverse: 'waypoints', async: false })
  region;

  @hasMany('meeting', { inverse: 'waypoint', async: false })
  meetings;

  @attr('string')
  name;

  @attr('string')
  author;

  @attr('string')
  call;

  @attr('string')
  excerpt;

  @attr('string')
  page;

  @attr('string')
  dimensions;

  @attr('string')
  outline;

  @attr('string')
  credit;

  @attr('string')
  status;

  @attr('createDate')
  createdAt;

  @attr('updateDate')
  updatedAt;

  get isComplete() {
    return this.schemas.fieldErrors.length === 0;
  }

  get isIncomplete() {
    return !this.isComplete;
  }

  get isAvailable() {
    return this.status === 'available';
  }
}
