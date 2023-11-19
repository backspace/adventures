import Controller from '@ember/controller';
import classic from 'ember-classic-decorator';

@classic
export default class SliceController extends Controller {
  queryParams = ['word', 'slices', 'debug', 'animated'];
  debug = false;
  animated = false;
  slices = 3;
  word = 'test';
}
