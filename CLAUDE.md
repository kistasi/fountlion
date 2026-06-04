# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

FountLion is a Cocoa app (Objective-C, ARC) targeting OS X 10.7 Lion for editing `.fountain` screenplay files. It renders Fountain markup with correct screenplay formatting (margins, fonts, colors) using a vendored parser, and supports character-name autocomplete and light/dark mode.

## Commands

```sh
make          # build and launch the app (opens build/fountlion.app)
make test     # build and run the XCTest suite
make clean    # remove the build/ directory
```

There is no way to run a single test file; `make test` runs all tests via `xctest`.

## Architecture

Source files live in `src/` and tests in `tests/`. The vendored parser is at `src/vendor/`.

**Entry point** — `src/main.m` hosts `AppDelegate`, which builds the menu bar and bootstraps `NSDocumentController`. No XIB/NIB: all UI is constructed in code.

**Document layer** — `FountainDocument` (subclass of `NSDocument`) owns the window, scroll view, text view, highlighter, and status bar. It handles file I/O (`readFromData:` / `dataOfType:`), color-scheme toggling, and status-bar updates.

**Highlighter** — `FountainHighlighter` is an `NSTextStorageDelegate`. On every edit it runs `FastFountainParser` over the full document text, maps each `FNElement` back to a character range by line index, and batch-applies `NSAttributedString` attributes (font + paragraph style + color). It also collects `characterNames` (sorted, extensions stripped) for autocomplete.

- Element type is inferred later by reading back `NSParagraphStyle.headIndent` from the text storage — the paragraph-style constants in `FountainHighlighter.m` are the single source of truth for both applying and reading back element types.
- Dark mode rebuilds only colors, not paragraph styles, and triggers a full re-highlight.

**Text view** — `FountainTextView` (subclass of `NSTextView`) adds two behaviors:

1. **Smart newline**: after a Character cue, sets typing attributes to Dialogue style immediately (before the async re-highlight fires).
2. **Autocomplete**: after each insertion on an all-caps line that looks like a character cue, triggers `complete:` using `characterNamesProvider` (a block wired in by `FountainDocument`).

**Status bar** — A 22 pt strip at the bottom of the window, built entirely in `FountainDocument`. Five subviews:

- `separatorView` — 1 pt top border line.
- `fileLabel` — left-aligned; shows the file path (tilde-abbreviated) or "Untitled" for unsaved documents.
- `countsLabel` — right-aligned; shows word and character counts, comma-formatted for ≥ 1000.
- `fontSizePopup` — NSPopUpButton with sizes 10–24 pt; selection persisted to `NSUserDefaults` key `"fontSize"` (default 14). `applyFontSize` reads this key and applies it to both the text view and `highlighter.fontSize`.
- `modeButton` — a checkbox that toggles dark mode via the responder chain (`toggleDarkMode:`).

`layoutStatusBar` positions all subviews from fixed constants (pad=8, btnW=90, popW=62, cntW=185), laid out right-to-left: modeButton → fontSizePopup → countsLabel → fileLabel. `updateStatusBar` recomputes content; both are called on window resize, file-URL changes, and text edits. Colors are set by `applyColorScheme` alongside the rest of the color scheme.

**Margin annotations** — `FountainTextView` overrides `drawRect:` to draw two sets of margin annotations after calling `super`:

- Scene numbers (sequential, starting at 1) are drawn right-aligned flush against the container's left edge, one per scene heading.
- Page numbers are drawn left of the container's right edge; only the first scene heading on each page triggers a page number. Page boundaries are computed by dividing the line-fragment Y offset by `kPageHeight` (792 pt, US Letter).
  Both use `highlighter.sceneHeadingRanges` (an array of `NSValue`-wrapped `NSRange`) populated during each highlight pass.

**Text container** — `centerTextView` (called on window resize and after setup) sizes the text container to `kContainerWidthFraction` (0.7) of the scroll view width, centers it with a symmetric horizontal inset, and repositions `leftBorderView`/`rightBorderView` (1 pt vertical lines) at the container edges. It also writes `containerWidth` to the highlighter so margin constants stay in sync.

**New document template** — untitled documents are pre-populated with a Fountain title-page block plus `FADE IN:` and a sample scene heading. The cursor is placed after `"Title: "` (offset 7).

**Vendor** — `src/vendor/`: `FastFountainParser` / `FNElement` / `NSString+Regex` are third-party (nyousefi/Fountain, MIT). Do not modify them; treat them as a stable API.

## Objective-C syntax: what works on Lion (10.7)

The app is compiled with the Clang version shipped with Xcode on Lion, which predates the "modern Objective-C" literals and subscripting introduced in Xcode 4.4 / LLVM 4.0. **Do not use any of the following:**

| Feature                    | Wrong                     | Right                                                            |
| -------------------------- | ------------------------- | ---------------------------------------------------------------- |
| Array literals             | `@[@"a", @"b"]`           | `[NSArray arrayWithObjects:@"a", @"b", nil]`                     |
| Empty array literal        | `@[]`                     | `[NSArray array]`                                                |
| Dictionary literals        | `@{@"k": @"v"}`           | `[NSDictionary dictionaryWithObject:@"v" forKey:@"k"]`           |
| Number literals            | `@42`, `@3.14`            | `[NSNumber numberWithInt:42]`, etc.                              |
| Array subscript read       | `arr[i]`                  | `[arr objectAtIndex:i]`                                          |
| Dictionary subscript read  | `dict[@"k"]`              | `[dict objectForKey:@"k"]`                                       |
| Array/dict subscript write | `arr[i] = x`              | `[arr replaceObjectAtIndex:i withObject:x]`                      |
| ObjC objects in C structs  | `struct { NSString *s; }` | Not allowed under ARC; use a helper method or separate variables |

**What does work:** ARC, blocks, `@property`/`@synthesize`, fast enumeration (`for … in`), `NSMutableArray`/`NSMutableDictionary`, string literals (`@"…"`), `instancetype`, `__weak`/`__strong`.

## Key constraints

- The page width is fixed at 612 pt (8.5" @ 72 dpi). All margin constants in `src/FountainHighlighter.m` are in points relative to that page width — change them there, not in paragraph-style build code scattered elsewhere.
- The text container width is dynamic (70% of scroll view width), not fixed. `highlighter.containerWidth` must be kept in sync via `centerTextView` so that the highlighter's scaled margin values remain correct.
- Highlighting is always a full-document pass (no incremental/range highlighting). The delayed-perform (`afterDelay:0.0`) in `textStorageDidProcessEditing:` coalesces rapid edits into one pass.
- `FountainDocument` uses `pendingContent` to buffer text loaded before the window is created (the NSDocument lifecycle calls `readFromData:` before `makeWindowControllers`).
- Font size and dark mode are persisted to `NSUserDefaults` (`"fontSize"`, `"darkMode"`). Both are read on launch via `applyFontSize` / `applyColorScheme`.
