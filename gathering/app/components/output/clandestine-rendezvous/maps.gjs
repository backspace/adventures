import { inject as service } from '@ember/service';
import Component from '@glimmer/component';
import blobStream from 'blob-stream';
import { storageFor } from 'ember-local-storage';
import { trackedFunction } from 'ember-resources/util/function';
import Loading from 'gathering/components/loading';
import Checkbox from 'gathering/components/output/checkbox';

import PDFDocument from 'pdfkit';

export default class ClandestineRendezvousMapsComponent extends Component {
  @service
  map;

  @storageFor('output') state;

  get lowResMap() {
    return this.state.get('clandestineRendezvousMapsLowResMap');
  }

  set lowResMap(value) {
    this.state.set('clandestineRendezvousMapsLowResMap', value);
  }

  generator = trackedFunction(this, async () => {
    const debug = this.args.debug;

    let sortedTeams = this.args.teams
      .slice()
      .sort((a, b) => a.createdAt - b.createdAt);

    let lowRes = this.lowResMap;

    const header = this.args.assets.header;
    const rendezvousLetterFont = this.args.assets.headerAlt;
    const doc = new PDFDocument({ layout: 'portrait', font: header });
    const stream = doc.pipe(blobStream());

    let mapBlob = this.args.assets.map;
    let lowMapBlob = this.args.assets.lowMap;

    let mapBitmap = await createImageBitmap(mapBlob);
    let lowMapBitmap = await createImageBitmap(lowMapBlob);

    let mapBase64String = await this.map.blobToBase64String(mapBlob);
    let lowMapBase64String = await this.map.blobToBase64String(lowMapBlob);

    const mapMarkerFontSize = 12;
    const mapMarkerCircleRadius = 10;

    const pageWidth = 8.5 * 72;
    const pageHeight = 11 * 72;

    const margin = 0.5 * 72;

    let gapAboveMap = 0;

    let innerWidth = pageWidth - margin * 2;
    let innerHeight = pageHeight / 2 - margin * 2;

    let innerWidthToMapHighRatio = (pageWidth - margin * 2) / mapBitmap.width;
    let innerWidthToMapLowRatio = (pageWidth - margin * 2) / lowMapBitmap.width;

    sortedTeams
      .slice()
      .sort((a, b) => a.createdAt - b.createdAt)
      .forEach((team, index) => {
        if (index > 0 && index % 2 === 0) {
          doc.addPage();
        }

        doc.save();

        if (index % 2 === 0) {
          doc.translate(margin, margin);
        } else {
          doc.translate(margin, pageHeight / 2 + margin);
        }

        doc.save();

        let ratio = lowRes ? innerWidthToMapLowRatio : innerWidthToMapHighRatio;
        let bitmap = lowRes ? lowMapBitmap : mapBitmap;
        let base64String = lowRes ? lowMapBase64String : mapBase64String;

        doc.translate(0, gapAboveMap);
        doc.scale(ratio, ratio);

        if (debug) {
          doc.rect(0, 0, bitmap.width, bitmap.height).stroke();
        } else {
          doc.image('data:image/png;base64,' + base64String, 0, 0);
        }

        doc.restore();

        doc.font(header);
        doc.fontSize(18);
        doc.text(team.get('name'), 0, 0);

        doc.fontSize(mapMarkerFontSize);

        doc.save();

        doc.font(rendezvousLetterFont);

        team
          .hasMany('meetings')
          .value()
          .slice()
          .sort((a, b) => a.index - b.index)
          .forEach((meeting, index) => {
            const destination = meeting.belongsTo('destination').value();
            const region = destination.belongsTo('region').value();
            const ancestorRegion = region.get('ancestor');

            const rendezvousLetter = String.fromCharCode(65 + index);

            const x =
              innerWidth * (ancestorRegion.get('x') / lowMapBitmap.width);
            const y =
              innerHeight * (ancestorRegion.get('y') / lowMapBitmap.height);

            doc.text(
              rendezvousLetter,
              x - mapMarkerCircleRadius,
              y + mapMarkerFontSize,
              {
                width: mapMarkerCircleRadius * 2,
                align: 'center',
              },
            );
          });

        doc.restore();

        const cropMarkLength = 1 * 72;

        doc.lineWidth(0.125);
        doc.strokeOpacity(0.25);

        doc
          .moveTo(
            pageWidth / 2 - margin - cropMarkLength / 2,
            pageHeight / 2 - margin,
          )
          .lineTo(
            pageWidth / 2 - margin + cropMarkLength / 2,
            pageHeight / 2 - margin,
          )
          .stroke();

        doc.restore();
      });

    doc.end();

    let blobUrl = await new Promise((resolve) => {
      stream.on('finish', () => {
        resolve(stream.toBlobURL('application/pdf'));
      });
    });

    return blobUrl;
  });

  get src() {
    return this.generator.value ?? undefined;
  }

  <template>
    <Checkbox
      class='mb-2'
      @id='low-res-map'
      @label='Low res map'
      @checked={{this.lowResMap}}
    />

    {{#if this.src}}
      <iframe title='maps' src={{this.src}}>
      </iframe>
    {{else}}
      <Loading />
    {{/if}}
  </template>
}
