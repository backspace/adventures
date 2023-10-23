import Controller from '@ember/controller';
import { tracked } from '@glimmer/tracking';
import classic from 'ember-classic-decorator';

@classic
export default class OutputController extends Controller {
  queryParams = [
    'debug',
    'unmnemonicDevicesOverlays',
    'unmnemonicDevicesTeamOverviews',
    'unmnemonicDevicesTeamOverviewsLowResMap',
    'unmnemonicDevicesVerification',
    'unmnemonicDevicesVrssql',
  ];

  @tracked debug = false;

  @tracked unmnemonicDevicesOverlays = false;
  @tracked unmnemonicDevicesTeamOverviews = false;
  @tracked unmnemonicDevicesTeamOverviewsLowResMap = true;
  @tracked unmnemonicDevicesVerification = false;
  @tracked unmnemonicDevicesVrssql = false;
}
