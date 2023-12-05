export function drawZigzagBackground(doc, width, height) {
  let overprint = 5;
  let zigzagWidth = 20;
  let zigzagHeight = 4;
  let lineWidth = 3;

  doc.save();

  doc.translate(-overprint, -overprint);
  width += overprint * 2;
  height += overprint * 2;

  doc.lineWidth(lineWidth);

  for (let y = 0; y < height; y += zigzagHeight * 2) {
    let path = `M 0,${y}`;
    let direction = 1;

    for (let x = 0; x < width; x += zigzagWidth) {
      let newX = x + zigzagWidth;
      let newY = y + direction * zigzagHeight;

      path += ` L ${newX},${newY}`;
      direction = -direction;
    }

    doc.path(path).stroke();
  }

  doc.restore();
}

export function drawConcentricCirclesBackground(doc, width, height) {
  let lineWidth = 2;

  let centreX = Math.random() * width;
  let centreY = Math.random() * height;

  // Calculate the maximum possible radius to cover the entire page
  let distances = [
    Math.sqrt(Math.pow(centreX, 2) + Math.pow(centreY, 2)),
    Math.sqrt(Math.pow(width - centreX, 2) + Math.pow(centreY, 2)),
    Math.sqrt(Math.pow(width - centreX, 2) + Math.pow(height - centreY, 2)),
    Math.sqrt(Math.pow(centreX, 2) + Math.pow(height - centreY, 2)),
  ];
  let maxRadius = Math.max(...distances);

  doc.lineWidth(lineWidth);

  for (let radius = lineWidth; radius < maxRadius; radius += lineWidth * 2) {
    doc.circle(centreX, centreY, radius).stroke();
  }
}

export function drawConcentricStarsBackground(doc, width, height) {
  let lineWidth = 2;
  let starPoints = 5;
  let innerToOuterRatio = 0.5;

  doc.lineWidth(lineWidth);

  // Choose a random point within the page width and height
  let centreX = Math.random() * width;
  let centreY = Math.random() * height;

  // Calculate the maximum possible radius to cover the entire page
  let distances = [
    Math.sqrt(Math.pow(centreX, 2) + Math.pow(centreY, 2)),
    Math.sqrt(Math.pow(width - centreX, 2) + Math.pow(centreY, 2)),
    Math.sqrt(Math.pow(width - centreX, 2) + Math.pow(height - centreY, 2)),
    Math.sqrt(Math.pow(centreX, 2) + Math.pow(height - centreY, 2)),
  ];
  let maxDistance = Math.max(...distances);
  let outerRadiusFactor = 1 / (1 - innerToOuterRatio);
  let maxRadius = maxDistance * outerRadiusFactor;

  for (let radius = lineWidth; radius < maxRadius; radius += lineWidth * 4) {
    let innerRadius = radius * innerToOuterRatio;
    let outerRadius = radius;

    drawStar(doc, centreX, centreY, innerRadius, outerRadius, starPoints);
  }
}

function drawStar(doc, centreX, centreY, innerRadius, outerRadius, starPoints) {
  let angle = Math.PI / starPoints;
  let path = '';

  for (let i = 0; i <= 2 * starPoints; i++) {
    let r = i % 2 === 0 ? outerRadius : innerRadius;
    let currX = centreX + r * Math.cos(i * angle);
    let currY = centreY - r * Math.sin(i * angle);

    if (i === 0) {
      path = `M ${currX},${currY}`;
    } else {
      path += ` L ${currX},${currY}`;
    }
  }

  doc.path(path).closePath().stroke();
}

export function drawSpiralBackground(doc, width, height) {
  let numSpiralArms = 180;
  let lineWidth = 2;
  let maxRadius =
    Math.sqrt(Math.pow(width, 2) + Math.pow(height, 2)) + lineWidth;

  // Choose a random starting point within a quarter of the page length from the center
  let centreX = width / 2;
  let centreY = height / 2;
  let quarterLength = Math.min(centreX, centreY) / 2;
  let startX = centreX + Math.random() * quarterLength - quarterLength / 2;
  let startY = centreY + Math.random() * quarterLength - quarterLength / 2;

  doc.lineWidth(lineWidth);

  for (let i = 0; i < numSpiralArms; i++) {
    let angleIncrement = (2 * Math.PI) / numSpiralArms;
    let angle = i * angleIncrement;
    let currentRadius = maxRadius;
    let endX = startX + currentRadius * Math.cos(2 * Math.PI + angle);
    let endY = startY + currentRadius * Math.sin(2 * Math.PI + angle);

    let control1X =
      startX + (currentRadius / 3) * Math.cos(Math.PI / 2 + angle);
    let control1Y =
      startY + (currentRadius / 3) * Math.sin(Math.PI / 2 + angle);
    let control2X =
      startX + ((2 * currentRadius) / 3) * Math.cos((3 * Math.PI) / 2 + angle);
    let control2Y =
      startY + ((2 * currentRadius) / 3) * Math.sin((3 * Math.PI) / 2 + angle);

    let path = `M ${startX},${startY} C ${control1X},${control1Y} ${control2X},${control2Y} ${endX},${endY}`;
    doc.path(path).stroke();
  }
}

export function drawDotGridBackground(doc, width, height) {
  let smallRadius = 1;
  let largeRadius = 2;
  let delta = 0.25;

  let cellSize = 5;

  let rows = height / cellSize;
  let cols = width / cellSize;

  doc.save();

  doc.fillColor('black');

  let startingRadius = smallRadius;
  let startingRadiusGrowing = true;

  for (let row = 0; row < rows; row++) {
    let radius = startingRadius;
    let radiusGrowing = true;

    for (let col = 0; col < cols; col++) {
      doc.circle(col * cellSize, row * cellSize, radius).fill();

      if (radiusGrowing) {
        radius += delta;

        if (radius > largeRadius) {
          radiusGrowing = false;
          radius = largeRadius - delta;
        }
      } else {
        radius -= delta;

        if (radius < smallRadius) {
          radiusGrowing = true;
          radius = smallRadius + delta;
        }
      }
    }

    if (startingRadiusGrowing) {
      startingRadius += delta;

      if (startingRadius > largeRadius) {
        startingRadiusGrowing = false;
        startingRadius = largeRadius - delta;
      }
    } else {
      startingRadius -= delta;

      if (startingRadius < smallRadius) {
        startingRadiusGrowing = true;
        startingRadius = smallRadius + delta;
      }
    }
  }

  doc.restore();
}

export function drawMazeBackground(doc, width, height) {
  doc.lineWidth(3);
  doc.lineCap('round');

  const cellSize = 4;
  const rows = Math.floor(height / cellSize);
  const cols = Math.floor(width / cellSize);

  const grid = new Array(rows).fill(null).map(() => new Array(cols).fill(true));

  function generateMaze(row, col) {
    const directions = ['up', 'down', 'left', 'right'];
    directions.sort(() => Math.random() - 0.65);

    for (const direction of directions) {
      let newRow = row;
      let newCol = col;

      switch (direction) {
        case 'up':
          newRow -= 2;
          break;
        case 'down':
          newRow += 2;
          break;
        case 'left':
          newCol -= 2;
          break;
        case 'right':
          newCol += 2;
          break;
      }

      if (
        newRow >= 0 &&
        newRow < rows &&
        newCol >= 0 &&
        newCol < cols &&
        grid[newRow][newCol]
      ) {
        grid[newRow][newCol] = false;
        grid[row][col] = false;

        const x1 = col * cellSize + cellSize / 2;
        const y1 = row * cellSize + cellSize / 2;
        const x2 = newCol * cellSize + cellSize / 2;
        const y2 = newRow * cellSize + cellSize / 2;

        doc.moveTo(x1, y1).lineTo(x2, y2).stroke();

        generateMaze(newRow, newCol);
      }
    }
  }

  generateMaze(0, 0);
}
