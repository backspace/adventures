import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';
import { trackedFunction } from 'ember-resources/util/function';
import { Input } from '@ember/component';

import blobStream from 'blob-stream';
import PDFDocument from 'pdfkit';

const pageMargin = 0.5 * 72;
const pagePadding = 0.25 * 72;

const registrationPadding = pagePadding;
const registrationLength = pagePadding;
const registrationTotal = registrationPadding + registrationLength;

const BACKGROUND_COUNT = 5;
const OUTLINE_WIDTH = 4;
const TEAM_FONT_SIZE = 14;
const TEAM_GAP_SIZE = pagePadding;

export default class UnmnemonicDevicesOverlaysComponent extends Component {
  @tracked allOverlays;

  @service('unmnemonic-devices') devices;

  generator = trackedFunction(this, async () => {
    let regular = this.args.assets.regular;

    let doc = new PDFDocument({ layout: 'portrait', font: regular });
    let stream = doc.pipe(blobStream());

    let waypointsToGenerate;

    if (this.allOverlays) {
      waypointsToGenerate = this.args.waypoints.filterBy('isComplete');
    } else {
      waypointsToGenerate = this.args.teams.reduce((waypoints, team) => {
        team.meetings.forEach((meeting) =>
          waypoints.push({ team, waypoint: meeting.get('waypoint') })
        );
        return waypoints;
      }, []);
    }

    waypointsToGenerate.forEach((maybeTeamAndWaypoint, index) => {
      let waypoint = maybeTeamAndWaypoint.waypoint || maybeTeamAndWaypoint;

      let dimensions = waypoint.get('dimensions');
      let regionAndCall = `${waypoint.get('region.name')}: ${waypoint.get(
        'call'
      )}`;
      let waypointName = waypoint.get('name');
      let excerpt = waypoint.get('excerpt');
      let outline = waypoint.get('outline');
      let page = waypoint.get('page');

      if (index > 0) {
        doc.addPage();
      }

      doc.save();
      doc.translate(pageMargin, pageMargin);

      let [width, height] = this.devices.parsedDimensions(dimensions);

      let team = maybeTeamAndWaypoint.team;

      doc.save();
      doc.translate(
        registrationLength + registrationPadding,
        registrationLength + registrationPadding
      );

      doc.lineWidth(0.25);

      // NW ver
      doc
        .moveTo(0, -registrationPadding)
        .lineTo(0, -registrationTotal)
        .stroke();

      // NW hor
      doc
        .moveTo(-registrationPadding, 0)
        .lineTo(-registrationTotal, 0)
        .stroke();

      // NE ver
      doc
        .moveTo(width, -registrationPadding)
        .lineTo(width, -registrationTotal)
        .stroke();

      // NE hor
      doc
        .moveTo(width + registrationPadding, 0)
        .lineTo(width + registrationTotal, 0)
        .stroke();

      let teamBottomMargin = team ? TEAM_FONT_SIZE + TEAM_GAP_SIZE : 0;

      doc.save();
      doc.translate(0, teamBottomMargin);

      // SW ver
      doc
        .moveTo(0, height + registrationPadding)
        .lineTo(0, height + registrationTotal)
        .stroke();

      // SW hor
      doc
        .moveTo(-registrationPadding, height)
        .lineTo(-registrationTotal, height)
        .stroke();

      // SE ver
      doc
        .moveTo(width, height + registrationPadding)
        .lineTo(width, height + registrationTotal)
        .stroke();

      // SE hor
      doc
        .moveTo(width + registrationPadding, height)
        .lineTo(width + registrationTotal, height)
        .stroke();

      // Maybe team margin
      doc.restore();

      doc.save();
      doc.rect(0, 0, width, height).clip();

      let backgroundIndex = index % BACKGROUND_COUNT;

      if (backgroundIndex === 1) {
        doc.image(
          this.args.assets.background1,
          -pageMargin * 2,
          -pageMargin * 2,
          {
            cover: [width + pageMargin * 4, height + pageMargin * 4],
            align: 'center',
            valign: 'center',
          }
        );
      } else {
        doc.image(this.args.assets[`background${backgroundIndex}`], 0, 0, {
          cover: [width, height],
          align: 'center',
          valign: 'center',
        });
      }

      doc.restore();

      doc.fontSize(14);

      let upperLeftText, upperRightText;

      if (page % 2 === 0) {
        upperLeftText = page;
        upperRightText = waypointName;
      } else {
        upperLeftText = waypointName;
        upperRightText = page;
      }

      doc
        .fillColor('black')
        .strokeColor('white')
        .lineWidth(OUTLINE_WIDTH)
        .text(upperLeftText, pagePadding, pagePadding, {
          fill: true,
          stroke: true,
        })
        .text(upperRightText, pagePadding, pagePadding, {
          width: width - pagePadding * 2,
          align: 'right',
          fill: true,
          stroke: true,
        })
        .text(
          regionAndCall,
          pagePadding,
          height - doc.currentLineHeight() - pagePadding,
          { stroke: true, fill: true }
        );

      doc
        .fillColor('black')
        .lineWidth(1)
        .text(upperLeftText, pagePadding, pagePadding)
        .text(upperRightText, pagePadding, pagePadding, {
          width: width - pagePadding * 2,
          align: 'right',
        })
        .text(
          regionAndCall,
          pagePadding,
          height - doc.currentLineHeight() - pagePadding
        );

      doc.strokeColor('black');

      let { end, points: outlinePoints } = this.devices.parsedOutline(outline);

      let [startX, startY] = outlinePoints.shift();

      doc.moveTo(startX, startY);

      outlinePoints.forEach(([displacementX, displacementY]) => {
        doc.lineTo(displacementX, displacementY);
      });

      doc.fillAndStroke('white', 'black');

      if (this.args.debug) {
        doc.text(dimensions, 0, height);
        doc.text(outline);
        doc.text(excerpt);
      }

      let preExcerpt = this.devices.preExcerpt(excerpt),
        postExcerpt = this.devices.postExcerpt(excerpt);

      doc.fontSize(10);

      doc
        .fillColor('black')
        .strokeColor('white')
        .lineWidth(OUTLINE_WIDTH)
        .text(preExcerpt, 0, startY, {
          align: 'right',
          fill: true,
          stroke: true,
          width: startX,
        })
        .text(postExcerpt, end[0], end[1], {
          stroke: true,
          fill: true,
        });

      doc
        .fillColor('black')
        .lineWidth(1)
        .text(preExcerpt, 0, startY, {
          align: 'right',
          width: startX,
        })
        .text(postExcerpt, end[0], end[1], {});

      if (team) {
        doc.fontSize(TEAM_FONT_SIZE);
        doc
          .fillColor('black')
          .text(
            team.name,
            pagePadding,
            height + TEAM_GAP_SIZE - TEAM_FONT_SIZE
          );
      }

      // Registration marks
      doc.restore();

      // Margins
      doc.restore();
    });

    doc.end();

    let blobUrl = await new Promise((resolve) => {
      stream.on('finish', () => {
        this.rendering = false;
        resolve(stream.toBlobURL('application/pdf'));
      });
    });

    return blobUrl;
  });

  get src() {
    return this.generator.value ?? undefined;
  }

  <template>
    <label>
      All overlays instead of per-team?
      <Input @type='checkbox' @checked={{this.allOverlays}} />
    </label>

    {{#if this.src}}
      <iframe title='embedded-unmnemonic-devices-overlays' src={{this.src}}>
      </iframe>
    {{else}}
      …
    {{/if}}
  </template>
}
