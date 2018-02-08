// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
import "deps/phoenix_html/web/static/js/phoenix_html"

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

// import socket from "./socket"

// TODO can create the SVG pixels here

const drawing = `
.............
. .       . .
.  .     .  .
.   .   .   .
.    . .    .
.     .     .
.............
`;

const allDrawingLines = drawing.split('\n');
const drawingLines = allDrawingLines.splice(1, allDrawingLines.length - 1);

$(() => {
  $("*[data-action=add-email]").click(function() {
    const email = $(this).closest("tr").children(".email").text();

    const teamEmails = $("#user_team_emails");
    const currentValue = teamEmails.val();

    if (currentValue.indexOf(email) == -1) {
      teamEmails.val(`${currentValue} ${email}`);
    }
  });

  drawingLines.forEach((line, rowIndex) => {
    line.split('').forEach((drawingPixel, colIndex) => {
      const pixel = $(`#p${rowIndex}-${colIndex}`);

      if (drawingPixel === '.') {
        pixel.attr('fill', 'white');
      } else {
        pixel.attr('fill', 'transparent');
      }
    });
  });
});
