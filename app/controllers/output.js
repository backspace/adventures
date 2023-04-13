import Controller from '@ember/controller';
import classic from 'ember-classic-decorator';

@classic
export default class OutputController extends Controller {
  queryParams = [
    'debug',
    'unmnemonicDevicesOverlays',
    'unmnemonicDevicesTeamOverviews',
    'unmnemonicDevicesVerification',
  ];

  debug = false;

  unmnemonicDevicesOverlays = false;
  unmnemonicDevicesTeamOverviews = false;
  unmnemonicDevicesVerification = false;
}
