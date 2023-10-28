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
    let lowRes = this.args.lowRes;

    let regular = this.args.assets.regular;

    let doc = new PDFDocument({ layout: 'portrait', font: regular });
    let stream = doc.pipe(blobStream());

    let mapBlob = this.args.assets.map;
    let lowMapBlob = this.args.assets.lowMap;

    let mapBitmap = await createImageBitmap(mapBlob);
    let lowMapBitmap = await createImageBitmap(lowMapBlob);

    let mapBase64String = await this.map.blobToBase64String(mapBlob);
    let lowMapBase64String = await this.map.blobToBase64String(lowMapBlob);

    let mapHighToLowRatio = lowMapBitmap.width / mapBitmap.width;

    let mapTeamFontSize = 18;
    let mapMarkerFontSize = 12;
    let mapMarkerCircleRadius = 10;

    let meetingHeadingFontSize = 14;
    let meetingBodyFontSize = 12;

    let pageWidth = 8.5 * 72;
    let pageHeight = 11 * 72;

    let margin = 0.5 * 72;

    let innerWidthToMapHighRatio = (pageWidth - margin * 2) / mapBitmap.width;
    let innerWidthToMapLowRatio = (pageWidth - margin * 2) / lowMapBitmap.width;

    let mapWidthOnPage = pageWidth - margin * 2;
    let mapHeightOnPage = (mapWidthOnPage * mapBitmap.height) / mapBitmap.width;

    let devices = this.devices;

    this.args.teams.forEach((team, index) => {
      if (index > 0) {
        doc.addPage();
      }

      drawMargins(doc, () => {
        drawHeader(team);
        drawMap();
        drawMeetingPoints(team);
        drawExtras();

        doc.addPage();

        drawMeetingBlanks(team);
      });
    });

    doc.end();

    let blobUrl = await new Promise((resolve) => {
      stream.on('finish', () => {
        resolve(stream.toBlobURL('application/pdf'));
      });
    });

    function drawHeader(team) {
      doc.save();
      doc.font(regular);
      doc.fontSize(mapTeamFontSize);
      doc.text(`${team.name}: ${team.identifier}`, 0, 0);
      doc.restore();
    }

    function drawMap() {
      doc.save();

      let ratio = lowRes ? innerWidthToMapLowRatio : innerWidthToMapHighRatio;
      let bitmap = lowRes ? lowMapBitmap : mapBitmap;
      let base64String = lowRes ? lowMapBase64String : mapBase64String;

      {
        doc.translate(0, mapTeamFontSize * 2);
        doc.scale(ratio, ratio);

        if (debug) {
          doc.rect(0, 0, bitmap.width, bitmap.height).stroke();
        } else {
          doc.image('data:image/png;base64,' + base64String, 0, 0);
        }
      }

      doc.restore();
    }

    function drawMeetingPoints(team) {
      doc.fontSize(mapMarkerFontSize);

      doc.save();
      const OUTLINE_WIDTH = 4;

      let OUTLINE_TEXT_ARGUMENTS = [
        {
          lineWidth: OUTLINE_WIDTH,
          strokeOpacity: 0.75,
          textOptions: { fill: true, stroke: true },
        },
        { lineWidth: 1, strokeOpacity: 1 },
      ];

      {
        doc.translate(0, mapTeamFontSize * 2);

        team
          .hasMany('meetings')
          .value()
          .sortBy('destination.id')
          .forEach((meeting, index) => {
            const rendezvousLetter = String.fromCharCode(65 + index);

            const waypoint = meeting.belongsTo('waypoint').value();
            const waypointRegion = waypoint.belongsTo('region').value();
            const waypointAncestor = waypointRegion.ancestor;

            const waypointX = waypointAncestor.x * innerWidthToMapLowRatio;
            const waypointY = waypointAncestor.y * innerWidthToMapLowRatio;

            const destination = meeting.belongsTo('destination').value();
            const destinationRegion = destination.belongsTo('region').value();
            const destinationAncestor = destinationRegion.ancestor;

            const destinationX =
              destinationAncestor.get('x') * innerWidthToMapLowRatio;
            const destinationY =
              destinationAncestor.get('y') * innerWidthToMapLowRatio;

            doc.save();
            {
              doc
                .circle(waypointX, waypointY, mapMarkerCircleRadius)
                .fillOpacity(0.25)
                .fillAndStroke('white', 'black');
              doc
                .circle(destinationX, destinationY, mapMarkerCircleRadius)
                .fillOpacity(0.25)
                .fillAndStroke('white', 'black');
            }
            doc.restore();

            drawArrow(doc, waypointX, waypointY, destinationX, destinationY);

            if (debug) {
              doc.text(
                `W ${waypointRegion.name}`,
                waypointX - mapMarkerCircleRadius,
                waypointY + mapMarkerFontSize,
                {
                  width: mapMarkerCircleRadius * 2,
                  align: 'center',
                }
              );
            }

            doc.save();

            // Print rendezvous letter with outline
            OUTLINE_TEXT_ARGUMENTS.forEach(
              ({ lineWidth, strokeOpacity, textOptions }) => {
                doc
                  .fillColor('black')
                  .strokeColor('white')
                  .strokeOpacity(strokeOpacity)
                  .lineWidth(lineWidth)
                  .text(
                    rendezvousLetter,
                    waypointX - mapMarkerCircleRadius,
                    waypointY - mapMarkerFontSize / 2,
                    {
                      align: 'center',
                      width: mapMarkerCircleRadius * 2,
                      ...textOptions,
                    }
                  );
              }
            );

            doc.restore();
            if (debug) {
              doc.text(
                `D ${destinationRegion.name}`,
                destinationX - mapMarkerCircleRadius,
                destinationY + mapMarkerFontSize,
                {
                  width: mapMarkerCircleRadius * 2,
                  align: 'center',
                }
              );
            }

            doc.save();

            // Print rendezvous letter with outline
            OUTLINE_TEXT_ARGUMENTS.forEach(
              ({ lineWidth, strokeOpacity, textOptions }) => {
                doc
                  .fillColor('black')
                  .strokeColor('white')
                  .strokeOpacity(strokeOpacity)
                  .lineWidth(lineWidth)
                  .text(
                    rendezvousLetter,
                    destinationX - mapMarkerCircleRadius,
                    destinationY - mapMarkerFontSize / 2,
                    {
                      align: 'center',
                      width: mapMarkerCircleRadius * 2,
                      ...textOptions,
                    }
                  );
              }
            );

            doc.restore();
          });
      }

      doc.restore();
    }

    function drawExtras() {
      doc.save();
      doc.translate(0, mapTeamFontSize * 4 + mapHeightOnPage);

      if (debug) {
        doc
          .rect(
            0,
            0,
            mapWidthOnPage,
            pageHeight - mapTeamFontSize * 4 - pageMargin * 2 - mapHeightOnPage
          )
          .stroke();
      }

      // Hackish reset of text position, unsure why but without this text was floating in the container, or even below it.
      doc.text('', 0, 0);
      doc.moveUp();

      doc.text('Extras go here');

      doc.restore();
    }

    function drawMeetingBlanks(team) {
      doc.save();
      doc.translate(pageMargin, pageMargin);

      let meetingCount = team.hasMany('meetings').value().length;

      let availableWidth = pageWidth - pageMargin * 2;
      let availableHeight = pageHeight - pageMargin * 2;

      let meetingHeight = availableHeight / meetingCount;
      let meetingWidth = availableWidth;

      let meetingLabelWidth = meetingBodyFontSize;
      let meetingHalfWidth =
        (meetingWidth - meetingLabelWidth - pagePadding) / 2;

      let meetingHalfWithoutPadding = meetingHalfWidth - pagePadding * 2;

      team
        .hasMany('meetings')
        .value()
        .sortBy('destination.id')
        .forEach((meeting, index) => {
          const rendezvousLetter = String.fromCharCode(65 + index);

          doc.save();

          doc.translate(0, index * meetingHeight);

          doc.fontSize(meetingHeadingFontSize);
          doc.text(rendezvousLetter, 0, pagePadding);

          doc.lineWidth(0.25);
          doc.moveTo(0, 0).lineTo(availableWidth, 0).stroke();
          doc
            .moveTo(meetingHalfWidth, pagePadding)
            .lineTo(meetingHalfWidth, meetingHeight - pagePadding)
            .stroke();

          let waypoint = meeting.belongsTo('waypoint').value();
          let waypointRegion = waypoint.belongsTo('region').value();

          // Draw waypoint
          {
            doc.save();

            doc.fontSize(meetingHeadingFontSize);
            doc.text(
              waypointRegion.name,
              meetingLabelWidth + pagePadding,
              pagePadding,
              {
                width: meetingHalfWithoutPadding,
              }
            );

            doc.fontSize(meetingBodyFontSize);

            let parent = waypointRegion.belongsTo('parent').value();

            while (parent) {
              doc.text(`In ${parent.name}. ${parent.notes}`);
              parent = parent.belongsTo('parent').value();
            }

            doc.text(waypoint.call);
            doc.text(' ');
            doc.text(devices.excerptWithBlanks(waypoint.excerpt), {
              width: meetingHalfWithoutPadding,
            });

            doc.restore();
          }

          let destination = meeting.belongsTo('destination').value();
          let destinationRegion = destination.belongsTo('region').value();

          // Draw destination
          {
            doc.save();
            doc.translate(meetingHalfWidth + pagePadding, 0);

            doc.fontSize(meetingHeadingFontSize);

            let parent = destinationRegion.belongsTo('parent').value();

            doc.text(destinationRegion.name, pagePadding, pagePadding, {
              width: meetingHalfWithoutPadding,
            });

            doc.fontSize(meetingBodyFontSize);

            while (parent) {
              doc.text(`In ${parent.name}`);
              parent = parent.belongsTo('parent').value();
            }

            doc.text(' ');
            doc.text(destination.mask, { width: meetingHalfWithoutPadding });

            doc.restore();
          }

          doc.restore();
        });

      doc.restore();
    }

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

function drawMargins(doc, callback) {
  doc.save();
  doc.translate(pageMargin, pageMargin);

  callback();
  doc.restore();
}

function drawArrow(doc, waypointX, waypointY, destinationX, destinationY) {
  // Configuration
  const arrowLength = 30;
  const arrowHeadSize = 7;

  if (waypointX === destinationX && waypointY === destinationY) {
    // If the waypoint and the destination are in the same region, draw a loop instead
    const loopRadius = arrowLength / 2;
    const startAngle = -Math.PI / 2;
    const endAngle = startAngle + (3 * Math.PI) / 2;
    doc
      .arc(waypointX, waypointY - loopRadius, loopRadius, startAngle, endAngle)
      .stroke();

    const arrowHeadStartX = waypointX - loopRadius;
    const arrowHeadOffsetY = -3;

    const arrowHeadX1 =
      arrowHeadStartX - (arrowHeadSize / 2) * Math.cos(Math.PI / 6);
    const arrowHeadY1 =
      waypointY - loopRadius + arrowHeadSize * Math.sin(Math.PI / 6);
    const arrowHeadX2 =
      arrowHeadStartX + (arrowHeadSize / 2) * Math.cos(Math.PI / 6);
    const arrowHeadY2 =
      waypointY - loopRadius + arrowHeadSize * Math.sin(Math.PI / 6);

    doc
      .moveTo(arrowHeadX1, arrowHeadOffsetY + arrowHeadY1)
      .lineTo(arrowHeadStartX, arrowHeadOffsetY + waypointY - loopRadius)
      .lineTo(arrowHeadX2, arrowHeadOffsetY + arrowHeadY2)
      .fill();
    return;
  }

  const directionX = destinationX - waypointX;
  const directionY = destinationY - waypointY;
  const magnitude = Math.sqrt(
    directionX * directionX + directionY * directionY
  );
  const unitDirectionX = directionX / magnitude;
  const unitDirectionY = directionY / magnitude;

  // End the body early so it doesn’t peek beyond the head
  const earlyEndX =
    waypointX + unitDirectionX * (arrowLength - arrowHeadSize / 2);
  const earlyEndY =
    waypointY + unitDirectionY * (arrowLength - arrowHeadSize / 2);

  const headX = waypointX + unitDirectionX * arrowLength;
  const headY = waypointY + unitDirectionY * arrowLength;

  doc.moveTo(waypointX, waypointY).lineTo(earlyEndX, earlyEndY).stroke();

  const arrowHeadAngle = Math.atan2(unitDirectionY, unitDirectionX);
  const arrowHeadX1 =
    headX - arrowHeadSize * Math.cos(arrowHeadAngle - Math.PI / 6);
  const arrowHeadY1 =
    headY - arrowHeadSize * Math.sin(arrowHeadAngle - Math.PI / 6);
  const arrowHeadX2 =
    headX - arrowHeadSize * Math.cos(arrowHeadAngle + Math.PI / 6);
  const arrowHeadY2 =
    headY - arrowHeadSize * Math.sin(arrowHeadAngle + Math.PI / 6);

  doc
    .moveTo(arrowHeadX1, arrowHeadY1)
    .lineTo(headX, headY)
    .lineTo(arrowHeadX2, arrowHeadY2)
    .fill();
}
