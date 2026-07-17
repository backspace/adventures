# Credits copy

The Credits page (`lib/routes/credits_route.dart`) reads each section's
body from a plain-text file in this directory:

| Section          | File                   |
| ---------------- | ---------------------- |
| Acknowledgements | `acknowledgements.txt` |
| Soundtrack       | `soundtrack.txt`       |
| Software         | `software.txt`         |

Write them as normal multi-line text — one entry per line, no escaping.
A blank line becomes a paragraph gap; an empty or missing file hides
that section.

These `.txt` files are gitignored so the real-world venue, soundtrack,
and stack aren't published to the public repo. This README is committed
only to keep the directory present, so a fresh clone still builds (with
all three sections hidden). Fill the files in on the machines that build
the app for real.
