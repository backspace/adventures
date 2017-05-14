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

$(() => {
  $("*[data-action=add-email]").click(function() {
    const email = $(this).closest("tr").children(".email").text();

    const teamEmails = $("#user_team_emails");
    const currentValue = teamEmails.val();

    if (currentValue.indexOf(email) == -1) {
      teamEmails.val(`${currentValue} ${email}`);
    }
  });

  const canvas = document.getElementById('canvas');

  if (canvas.getContext) {
    const ctx = canvas.getContext('2d');

    const pixelSize = 8;
    const gridSize = 1;
    ctx.imageSmoothingEnabled = false;
    // ctx.translate(0.5, 0.5);

    function drawPixel(x, y) {
      ctx.fillStyle = 'black';
      ctx.fillRect(x*pixelSize + gridSize, y*pixelSize + gridSize, pixelSize - gridSize*2, pixelSize - gridSize*2);
      // ctx.fillRect(x*pixelSize, y*pixelSize, pixelSize, pixelSize);
      // ctx.strokeStyle = 'rgba(255, 255, 255, 0.25)';
      // ctx.strokeRect(x*pixelSize + gridSize, y*pixelSize + gridSize, pixelSize - gridSize*2, pixelSize - gridSize*2);
    }

    function drawRect(x, y, w, h) {
      for (let xi = x, xn = x + w; xi < xn; xi++) {
        for (let yi = y, yn = y + h; yi < yn; yi++) {
          drawPixel(xi, yi);
        }
      }
    }

    // drawPixel(1, 1);
    // drawPixel(2, 1);
    // drawPixel(3, 1);
    //
    // drawRect(5, 10, 10, 10);

    ctx.translate(-pixelSize*3, 0);

    drawRect(3, 0, 4, 7);
    drawRect(3, 8, 3, 7);
    drawRect(3, 16, 2, 7);
    drawRect(3, 24, 2, 7);

    // Antenna
    drawRect(3, 32, 5, 1);
    drawPixel(3, 33);
    drawPixel(5, 33);
    drawPixel(7, 33);
    drawRect(4, 34, 3, 1);
    drawRect(5, 34, 1, 3);
  }
});
