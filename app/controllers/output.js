import classic from 'ember-classic-decorator';
import Controller from '@ember/controller';

@classic
export default class OutputController extends Controller {
  queryParams = ['debug'];
  debug = false;
}
