# Instructions briefing

The Instructions page (`lib/routes/instructions_route.dart`) renders a single
Markdown file from this directory:

| File              | Shown                                            |
| ----------------- | ------------------------------------------------ |
| `instructions.md` | On the Instructions page once the event has begun |

Before the simulation starts, the page shows a placeholder
("Check back here for instructions once the simulation has begun") and the
file stays sealed. Once it starts, `instructions.md` is rendered.

Write it as Markdown. The in-app renderer (`widgets/markdown_view.dart`) is a
small subset of CommonMark — headings (`#`/`##`/`###`), unordered/ordered
lists (with two-space nesting), horizontal rules (`---`), paragraphs, and
inline `**bold**` / `*italic*` / `` `code` ``. No tables, images, links, or
blockquotes.

`instructions.md` is **gitignored** so the storyline briefing isn't published
to the public repo — this mirrors the credits copy. This README is committed
only to keep the directory present, so a fresh clone still builds (with the
Instructions page showing a short "no instructions" note after the event
starts). Drop `instructions.md` in on the machines that build the app for
real.
