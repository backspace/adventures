import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { trackedFunction } from 'ember-resources/util/function';
import { inject as service } from '@ember/service';

import blobStream from 'blob-stream';
import PDFDocument from 'pdfkit';

const pageMargin = 0.5 * 72;
const pagePadding = 0.25 * 72;

export default class TeamOverviewsComponent extends Component {
  @service map;
  @service('unmnemonic-devices') devices;

  generator = trackedFunction(this, async () => {
    let debug = this.args.debug;

    let regular = this.args.assets.regular;

    let doc = new PDFDocument({ layout: 'portrait', font: regular });
    let stream = doc.pipe(blobStream());

    let mapBlob = this.args.assets.map;
    let lowMapBlob = this.args.assets.lowMap;

    let mapBitmap = await createImageBitmap(mapBlob);
    let lowMapBitmap = await createImageBitmap(lowMapBlob);

    let map = await this.map.blobToBase64String(mapBlob);

    let mapHighToLowRatio = lowMapBitmap.width / mapBitmap.width;

    let mapOffsetX = 0;
    let mapOffsetY = 10;

    let mapClipTop = 50;
    let mapClipLeft = 0;

    let mapTeamFontSize = 18;
    let mapMarkerFontSize = 12;
    let mapMarkerCircleRadius = 10;

    let pageWidth = 8.5 * 72;
    let pageHeight = 11 * 72;

    let margin = 0.5 * 72;

    this.args.teams.forEach((team, index) => {
      if (index > 0) {
        doc.addPage();
      }

      doc.save();
      doc.translate(margin, margin);

      if (!debug) {
        doc.save();

        doc.translate(0, mapTeamFontSize);

        doc
          .rect(0, 0, pageWidth - mapClipLeft, pageHeight / 2 - mapClipTop)
          .clip();
        doc.image(
          'data:image/png;base64,' + map,
          mapOffsetX - mapClipLeft,
          mapOffsetY - mapClipTop,
          { scale: mapHighToLowRatio }
        );

        doc.restore();
      }

      doc.font(regular);
      doc.fontSize(mapTeamFontSize);
      doc.text(`${team.name}: ${team.identifier}`, 0, 0);

      doc.fontSize(mapMarkerFontSize);

      doc.save();
      doc.translate(0, mapTeamFontSize);

      team
        .hasMany('meetings')
        .value()
        .sortBy('index')
        .forEach((meeting, index) => {
          const rendezvousLetter = String.fromCharCode(65 + index);

          const destination = meeting.belongsTo('destination').value();
          const destinationRegion = destination.belongsTo('region').value();

          const destinationX =
            destinationRegion.get('x') / 2 + mapOffsetX - mapClipLeft;
          const destinationY =
            destinationRegion.get('y') / 2 + mapOffsetY - mapClipTop;

          doc.text(
            `${rendezvousLetter}-D FIXPOS`,
            destinationX - mapMarkerCircleRadius,
            destinationY + mapMarkerFontSize,
            {
              width: mapMarkerCircleRadius * 2,
              align: 'center',
            }
          );

          const waypoint = meeting.belongsTo('waypoint').value();
          const waypointRegion = waypoint.belongsTo('region').value();

          const waypointX = waypointRegion.x / 2 + mapOffsetX - mapClipLeft;
          const waypointY = waypointRegion.y / 2 + mapOffsetY - mapClipTop;

          doc.text(
            `${rendezvousLetter}-W FIXPOS`,
            waypointX - mapMarkerCircleRadius,
            waypointY + mapMarkerFontSize,
            {
              width: mapMarkerCircleRadius * 2,
              align: 'center',
            }
          );
        });

      doc.restore();

      doc.translate(0, pageHeight / 2);

      team
        .hasMany('meetings')
        .value()
        .sortBy('index')
        .forEach((meeting) => {
          let waypoint = meeting.belongsTo('waypoint').value();
          let waypointRegion = waypoint.belongsTo('region').value();

          let destination = meeting.belongsTo('destination').value();

          doc.text(
            `Library ${waypointRegion.name}, book ${waypoint.name}, call in with phrase, destination mask ${destination.mask}`
          );
        });

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
    {{#if this.src}}
      <iframe title='team-overviews' src={{this.src}}>
      </iframe>
    {{else}}
      …
    {{/if}}
  </template>
}
