import { inject as service } from '@ember/service';
import Component from '@glimmer/component';
import Loading from 'gathering/components/loading';
import Checkbox from 'gathering/components/output/checkbox';
import blobStream from 'blob-stream';
import { storageFor } from 'ember-local-storage';
import { trackedFunction } from 'ember-resources/util/function';
import truncate from 'lodash.truncate';

import PDFDocument from 'pdfkit';

import {
  drawMazeBackground,
  drawZigzagBackground,
  drawConcentricCirclesBackground,
  drawConcentricStarsBackground,
  drawDotGridBackground,
} from './overlay-backgrounds';

const BACKGROUNDS = [
  drawMazeBackground,
  drawZigzagBackground,
  drawConcentricCirclesBackground,
  drawDotGridBackground,
  drawConcentricStarsBackground,
];

export const PAGE_MARGIN = 0.3 * 72;
export const PAGE_PADDING = 0.2 * 72;

export const TEXT_OUTLINE_WIDTH = 4;
export const TEAM_FONT_SIZE = 14;
export const TEAM_GAP_SIZE = PAGE_PADDING;
export const EXCERPT_HEIGHT = 10;
export const EXCERPT_GAP = 5;
export const OUTLINE_LINE_WIDTH = 0.25;

let OUTLINE_TEXT_ARGUMENTS = [
  { lineWidth: TEXT_OUTLINE_WIDTH, textOptions: { fill: true, stroke: true } },
  { lineWidth: 1 },
];

let registrationPadding = PAGE_PADDING / 2;
let registrationLength = PAGE_PADDING / 2;
let registrationTotal = registrationPadding + registrationLength;

export default class UnmnemonicDevicesOverlaysComponent extends Component {
  @service('unmnemonic-devices') devices;

  @storageFor('output') state;

  get allOverlays() {
    return this.state.get('unmnemonicDevicesOverlaysAll');
  }

  set allOverlays(value) {
    this.state.set('unmnemonicDevicesOverlaysAll', value);
  }

  get onlyUnknownStatus() {
    return this.state.get('unmnemonicDevicesOverlaysonlyUnknownStatus');
  }

  set onlyUnknownStatus(value) {
    this.state.set('unmnemonicDevicesOverlaysonlyUnknownStatus', value);
  }

  generator = trackedFunction(this, async () => {
    let regular = this.args.assets.regular;

    let doc = new PDFDocument({ layout: 'portrait', font: regular });
    let stream = doc.pipe(blobStream());

    let waypointsToGenerate;

    if (this.allOverlays) {
      waypointsToGenerate = this.args.waypoints.filter((w) => w.isComplete);

      if (this.onlyUnknownStatus) {
        waypointsToGenerate = waypointsToGenerate.filter(
          (w) => w.status !== 'available' && w.status !== 'unavailable',
        );
      }
    } else {
      waypointsToGenerate = this.args.teams.reduce((waypoints, team) => {
        team
          .hasMany('meetings')
          .value()
          .slice()
          .sort((a, b) => a.destination.id - b.destination.id)
          .forEach((meeting, index) => {
            waypoints.push({
              team,
              waypoint: meeting.get('waypoint'),
              identifierForMeeting: this.devices.identifierForMeeting(index),
            });
          });

        return waypoints;
      }, []);
    }

    waypointsToGenerate.forEach((maybeTeamAndWaypoint, index) => {
      let waypoint = maybeTeamAndWaypoint.waypoint || maybeTeamAndWaypoint;

      let dimensions = waypoint.get('dimensions');
      let region = waypoint.get('region.name');
      let call = waypoint.get('call');
      let waypointName = waypoint.get('name');
      let excerpt = waypoint.get('excerpt');
      let fullOutline = waypoint.get('outline');
      let page = waypoint.get('page');

      if (index > 0) {
        doc.addPage();
      }

      doc.save();
      doc.translate(PAGE_MARGIN, PAGE_MARGIN);

      let [width, height] = this.devices.parsedDimensions(dimensions);

      let team = maybeTeamAndWaypoint.team;
      let teamBottomMargin = team ? TEAM_FONT_SIZE + TEAM_GAP_SIZE : 0;

      drawRegistrationMarks(doc, width, height, teamBottomMargin);

      if (!this.args.debug) {
        drawBackground(doc, width, height, index);
      }

      doc.fontSize(14);
      drawHeaderAndFooterText(
        doc,
        width,
        height,
        page,
        waypointName,
        region,
        call,
        maybeTeamAndWaypoint.identifierForMeeting || 'X',
      );

      doc.strokeColor('black');

      let outlines = this.devices.parsedOutline(fullOutline);

      outlines.forEach((outline, index) => {
        let first = index == 0;
        let last = index == outlines.length - 1;

        let { end, points: outlinePoints } = outline;

        let [startX, startY] = outlinePoints.shift();

        doc.moveTo(startX, startY);

        outlinePoints.forEach(([displacementX, displacementY]) => {
          doc.lineTo(displacementX, displacementY);
        });

        doc.lineWidth(OUTLINE_LINE_WIDTH);
        doc.fillAndStroke('white', 'black');

        let preExcerpt = this.devices.preExcerpt(excerpt),
          postExcerpt = this.devices.postExcerpt(excerpt);

        doc.fontSize(EXCERPT_HEIGHT);

        let preExcerptWidth = doc.widthOfString(preExcerpt);
        let postExcerptWidth = doc.widthOfString(postExcerpt);

        let preExcerptX = 0,
          preExcerptY = startY,
          preExcerptAlign = 'right',
          preExcerptWidthObject = { width: startX - EXCERPT_GAP };

        if (startX - preExcerptWidth < PAGE_PADDING) {
          preExcerptX = 0;
          preExcerptY -= EXCERPT_HEIGHT;
          preExcerptAlign = 'right';
          preExcerptWidthObject = { width: width - PAGE_PADDING };
        }

        let postExcerptX = end[0] + EXCERPT_GAP,
          postExcerptY = end[1],
          postExcerptAlign = 'left';

        if (end[0] + postExcerptWidth > width - PAGE_PADDING) {
          postExcerptX = PAGE_PADDING;
          postExcerptY += EXCERPT_HEIGHT;
          postExcerptAlign = 'left';
        }

        // Print text outlines and then text atop them
        OUTLINE_TEXT_ARGUMENTS.forEach(({ lineWidth, textOptions }) => {
          if (first) {
            doc
              .fillColor('black')
              .strokeColor('white')
              .lineWidth(lineWidth)
              .text(preExcerpt, preExcerptX, preExcerptY, {
                align: preExcerptAlign,
                ...preExcerptWidthObject,
                ...textOptions,
              });
          }

          if (last) {
            doc
              .fillColor('black')
              .strokeColor('white')
              .lineWidth(lineWidth)
              .text(postExcerpt, postExcerptX, postExcerptY, {
                align: postExcerptAlign,
                ...textOptions,
              });
          }
        });
      });

      if (this.args.debug) {
        doc.save();
        doc.fontSize(8);
        doc.text(dimensions);
        doc.text(fullOutline);
        doc.text(excerpt);

        outlines.forEach((outline) => {
          doc.text(JSON.stringify(outline));
        });

        doc.restore();
      }

      if (team) {
        doc.fontSize(TEAM_FONT_SIZE);
        doc
          .fillColor('black')
          .text(
            team.truncatedName,
            PAGE_PADDING,
            height + TEAM_GAP_SIZE - TEAM_FONT_SIZE / 2,
            { lineBreak: false },
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
        resolve(stream.toBlobURL('application/pdf'));
      });
    });

    return blobUrl;
  });

  get src() {
    return this.generator.value ?? undefined;
  }

  <template>
    <section class='flex gap-2 mb-2'>
      <Checkbox
        @label='All books'
        @id='all-books'
        @checked={{this.allOverlays}}
      />

      {{#if this.allOverlays}}
        <Checkbox
          @label='Only unknown status'
          @id='only-unknown-status'
          @checked={{this.onlyUnknownStatus}}
        />
      {{/if}}
    </section>

    {{#if this.src}}
      <iframe title='overlays' src={{this.src}}>
      </iframe>
    {{else}}
      <Loading />
    {{/if}}
  </template>
}

function drawRegistrationMarks(doc, width, height, teamBottomMargin) {
  doc.save();
  doc.translate(
    registrationLength + registrationPadding,
    registrationLength + registrationPadding,
  );

  doc.lineWidth(0.25);

  // NW ver
  doc.moveTo(0, -registrationPadding).lineTo(0, -registrationTotal).stroke();

  // NW hor
  doc.moveTo(-registrationPadding, 0).lineTo(-registrationTotal, 0).stroke();

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
}

function drawBackground(doc, width, height, pageIndex) {
  doc.save();
  doc.rect(0, 0, width, height).clip();

  let backgroundIndex = pageIndex % BACKGROUNDS.length;
  let backgroundFunction = BACKGROUNDS[backgroundIndex];

  backgroundFunction(doc, width, height);

  doc.restore();
}

function drawHeaderAndFooterText(
  doc,
  width,
  height,
  page,
  waypointName,
  region,
  call,
  identifier,
) {
  let upperLeftText, upperRightText;

  if (page % 2 === 0) {
    upperLeftText = page;
    upperRightText = waypointName;
  } else {
    upperLeftText = waypointName;
    upperRightText = page;
  }

  let maybeTruncatedRegion = region;
  let lengthAfterTruncation = maybeTruncatedRegion.length;
  let widthOfIdentifier = doc.widthOfString(identifier);
  let widthOfColonAndCall = doc.widthOfString(': ' + call);

  while (
    doc.widthOfString(maybeTruncatedRegion) + widthOfColonAndCall >
      width - widthOfIdentifier - PAGE_PADDING * 3 &&
    maybeTruncatedRegion.length > 0
  ) {
    lengthAfterTruncation--;
    maybeTruncatedRegion = truncate(region, {
      length: lengthAfterTruncation,
      separator: /:,? +/,
      omission: '…',
    });
  }

  let regionAndCall = `${maybeTruncatedRegion}: ${call}`;

  // Draw string outlines in their respective corners and then the strings themselves
  OUTLINE_TEXT_ARGUMENTS.forEach(({ lineWidth, textOptions }) => {
    doc
      .fillColor('black')
      .strokeColor('white')
      .lineWidth(lineWidth)
      .text(upperLeftText, PAGE_PADDING, PAGE_PADDING, {
        ...textOptions,
      })
      .text(upperRightText, PAGE_PADDING, PAGE_PADDING, {
        width: width - PAGE_PADDING * 2,
        align: 'right',
        ...textOptions,
      })
      .text(
        regionAndCall,
        PAGE_PADDING,
        height - doc.currentLineHeight() - PAGE_PADDING,
        { ...textOptions },
      )
      .text(
        identifier || '',
        PAGE_PADDING,
        height - doc.currentLineHeight() - PAGE_PADDING,
        { width: width - PAGE_PADDING * 2, align: 'right', ...textOptions },
      );
  });
}
