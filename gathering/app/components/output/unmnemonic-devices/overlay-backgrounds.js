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
