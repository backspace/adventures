import Service from '@ember/service';

export default class UnmnemonicDevicesService extends Service {
  descriptionIsValid() {
    return true;
  }

  maskIsValid() {
    return true;
  }
}
