import Component from '@ember/component';
import { inject as service } from '@ember/service';
import { tagName } from '@ember-decorators/component';
import blobStream from 'blob-stream';
import classic from 'ember-classic-decorator';
import { trackedFunction } from 'ember-resources/util/function';

import PDFDocument from 'pdfkit';

@classic
@tagName('span')
export default class clandestineRendezvousMapsComponent extends Component {
  @service
  map;

  generator = trackedFunction(this, async () => {
    const debug = this.debug;

    const header = this.get('assets.header');
    const doc = new PDFDocument({ layout: 'portrait', font: header });
    const stream = doc.pipe(blobStream());

    const mapBlob = this.get('assets.map');
    const map = await this.map.blobToBase64String(mapBlob);

    const mapOffsetX = 0;
    const mapOffsetY = 0;

    const mapClipTop = 50;
    const mapClipLeft = 0;

    const mapMarkerFontSize = 12;
    const mapMarkerCircleRadius = 10;

    const pageWidth = 8.5 * 72;
    const pageHeight = 11 * 72;

    const margin = 0.5 * 72;

    this.teams.forEach((team, index) => {
      if (index > 0 && index % 2 === 0) {
        doc.addPage();
      }

      doc.save();

      if (index % 2 === 0) {
        doc.translate(margin, margin);
      } else {
        doc.translate(margin, pageHeight / 2 + margin);
      }

      if (!debug) {
        doc.save();

        doc
          .rect(0, 0, pageWidth - mapClipLeft, pageHeight / 2 - mapClipTop)
          .clip();
        doc.image(
          'data:image/png;base64,' + map,
          mapOffsetX - mapClipLeft,
          mapOffsetY - mapClipTop,
          { scale: 0.125 }
        );

        doc.restore();
      }

      doc.font(header);
      doc.fontSize(18);
      doc.text(team.get('name'), 0, 0);

      doc.fontSize(mapMarkerFontSize);

      team
        .hasMany('meetings')
        .value()
        .sortBy('index')
        .forEach((meeting, index) => {
          const destination = meeting.belongsTo('destination').value();
          const region = destination.belongsTo('region').value();

          const rendezvousLetter = String.fromCharCode(65 + index);

          const x = region.get('x') / 2 + mapOffsetX - mapClipLeft;
          const y = region.get('y') / 2 + mapOffsetY - mapClipTop;

          doc.text(
            rendezvousLetter,
            x - mapMarkerCircleRadius,
            y + mapMarkerFontSize,
            {
              width: mapMarkerCircleRadius * 2,
              align: 'center',
            }
          );
        });

      const cropMarkLength = 1 * 72;

      doc.lineWidth(0.125);
      doc.strokeOpacity(0.25);

      doc
        .moveTo(
          pageWidth / 2 - margin - cropMarkLength / 2,
          pageHeight / 2 - margin
        )
        .lineTo(
          pageWidth / 2 - margin + cropMarkLength / 2,
          pageHeight / 2 - margin
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
}
