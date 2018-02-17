
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
  }, 0);
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

export { characters, characterLines, characterWidths, wordWidth, wordLines };
