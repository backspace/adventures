const pixelLength = 5;
const pixelMargin = 0.5;
const drawnLength = pixelLength - pixelMargin;

const heightInPixels = 8;

const registrationLength = pixelLength;

const characters = {
  A:
` ...
 .. ..
 .. ..
 .. ..
 .....
 .. ..
 .. ..
`,
  B:
`
....
.. ..
....
.. ..
.. ..
.. ..
....
`,
  'C':
`
 .....
..
..
..
..
..
 .....
`,
  'D':
`
....
.. ..
.. ..
.. ..
.. ..
.. ..
....
`,
  I:
`
..
..
..
..
..
..
..
`,
  'M':
`
.     .
..   ..
... ...
.......
.. . ..
..   ..
..   ..
`,
  N:
`
.   ..
..  ..
... ..
......
.. ...
..  ..
..   .
`,
  U:
`
.. ..
.. ..
.. ..
.. ..
.. ..
.. ..
 ...
`,
  X:
`
..  ..
..  ..
 ....
  ..
 ....
..  ..
..  ..
`,
  'a':
`


 ...
   ..
 ....
.. ..
 ....
`,
  'b':
`
..
..
....
.. ..
.. ..
.. ..
....
`,
  c:
`


 ...
..
..
..
 ...
`,
  'd':
`
   ..
   ..
 ....
.. ..
.. ..
.. ..
 ....
`,
  'e':
`


 ...
.. ..
.....
..
 ....
`,
  'f':
`
 ..
..
...
..
..
..
..
`,
  g:
`


 ....
.. ..
.. ..
 ....
   ..
 ...
`,
  'h':
`
..
..
....
.. ..
.. ..
.. ..
.. ..
`,
  i:
`
..

..
..
..
..
..
`,
  'l':
`
..
..
..
..
..
..
..
`,
m:
`


.......
.. .. ..
.. .. ..
.. .. ..
.. .. ..
`,
  'n':
`


....
.. ..
.. ..
.. ..
.. ..
`,
  'o':
`


 ...
.. ..
.. ..
.. ..
 ...
`,
  'p':
`


....
.. ..
.. ..
....
..
..
`,
  r:
`


.. .
....
..
..
..
`,
  's':
`


 ...
..
....
  ..
...
`,
  't':
`
..
..
...
..
..
..
 ..
`,
  u:
`


.. ..
.. ..
.. ..
.. ..
 ....
`,
  v:
`


.. ..
.. ..
 ...
 ...
  .
`,
  'w':
`


..   ..
.. . ..
.. . ..
 .....
 .. ..
`,
  y:
`


.. ..
.. ..
.. ..
 ....
   ..
 ...
`,
  '0':
`
 ...
.. ..
.. ..
.. ..
.. ..
.. ..
 ...
`,
  '1':
`
 ..
...
 ..
 ..
 ..
 ..
 ..
`,
  '2':
`
....
   ..
   ..
 ...
..
..
.....
`,
  '4':
`
   ..
  ...
 . ..
.  ..
.....
   ..
   ..
`,
  '5':
`
....
.
....
   ..
   ..
   ..
....
`,
  '8':
`
 ...
.. ..
.. ..
 ...
.. ..
.. ..
 ...
`,
  '9':
`
 ...
.. ..
.. ..
.. ..
 ....
   ..
 ...
`,
  ' ':
`

`
};

const characterWidths = Object.keys(characters).reduce((widths, character) => {
  widths[character] = Math.max(...characters[character].split('\n').map(line => line.length));
  return widths;
}, {});

const characterLines = Object.keys(characters).reduce((lines, character) => {
  const allLines = characters[character].split('\n');
  const maxWidth = Math.max(...allLines.map(line => line.length));
  const slicedLines = allLines.slice(1, allLines.length - 1);

  lines[character] = slicedLines.map(line => {
    return line.padEnd(maxWidth, ' ');
  });

  for (; lines[character].length < 8;) {
    lines[character].push(' '.repeat(maxWidth));
  }

  return lines;
}, {});

function wordWidth(word) {
  return word.split('').reduce((width, character) => {
    return width + (characterWidths[character] || 0) + 1;
  }, 0) - 1;
}

function wordLines(word) {
  const knownCharacterLines = word.split('').map(character => {
    const lines = characterLines[character];

    if (lines) {
      return lines;
    } else {
      throw Error(`Unable to find character lines for ${character}`);
    }
  });

  const lines = [];

  for (let line = 0; line < 8; line++) {
    lines.push(knownCharacterLines.map(lines => lines[line]).join(' '));
  }

  return lines;
}

function pointDimensionsForDisplay(word, displaySize) {
  const heightInPixelsWithMarks = heightInPixels + 1;
  const widthInPixelsWithMarks = wordWidth(word) + 1;

  const displayDiagonalInPoints = displaySize*72;

  const diagonalInPixelsWithMarks = Math.sqrt(Math.pow(heightInPixelsWithMarks, 2) + Math.pow(widthInPixelsWithMarks, 2));

  const pointsPerPixel = displayDiagonalInPoints/diagonalInPixelsWithMarks;

  return {
    pointsPerPixel,
    width: widthInPixelsWithMarks*pointsPerPixel,
    height: heightInPixelsWithMarks*pointsPerPixel
  };
}

function drawString({string, slices, teamPosition, debug}, drawFunction) {
  const lines = wordLines(string);
  const height = lines.length;

  let characterIndex = 0;

  for (let row = 0; row < height; row++) {
    const line = lines[row];
    const width = line.length;

    for (let col = 0; col < width; col++) {
      let fill = 'transparent';

      if (lines[row][col] === '.') {
        if (characterIndex % slices === teamPosition) {
          fill = 'black';
        } else if (debug) {
          fill = 'yellow';
        }
      }

      drawFunction(row, col, fill);

      characterIndex++;
    }
  }
}

export {
  pixelLength,
  pixelMargin,
  drawnLength,
  registrationLength,
  heightInPixels,
  characters,
  characterLines,
  characterWidths,
  wordWidth,
  wordLines,
  drawString,
  pointDimensionsForDisplay
};
