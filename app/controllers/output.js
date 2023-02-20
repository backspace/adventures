import Controller from '@ember/controller';
import classic from 'ember-classic-decorator';

@classic
export default class OutputController extends Controller {
  queryParams = ['debug'];
  debug = false;
}
