import Component from '@ember/component';
import classic from 'ember-classic-decorator';

@classic
export default class DraggableNumber extends Component {
  didInsertElement() {
    super.didInsertElement();

    // FIXME restore…? but this would be a modifier now ya
    // $(this.element).find('input').draggableNumber();
  }
}
