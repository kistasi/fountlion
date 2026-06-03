# FountLion

A [Fountain](https://fountain.io) screenplay editor for OS X 10.7 Lion.

## Features

- Syntax highlighting with standard screenplay margins (scene headings, action, character, dialogue, parenthetical, transition)
- Scene numbers in the left margin and page numbers in the right margin
- Bordered text column (left/right rules) that recenters on window resize
- Character name autocomplete
- Status bar with file path, word/character count, font size picker (10–24 pt), and dark mode toggle
- Light and dark mode (persisted across launches)
- Find panel (Cmd+F, Cmd+G)
- New documents open with a Fountain title-page template
- Native `.fountain` file association

## Build

Requires Xcode installed at `/Applications/Xcode.app`.

```sh
make        # build and launch
make test   # run tests
make clean  # remove build artifacts
```

## Fountain format

Fountain is a plain-text markup language for screenplays. See [fountain.io](https://fountain.io) for the spec. A sample script (`Big-Fish.fountain`) is included in the repo.

## Credits

The Fountain parser in `src/vendor/` is based on [nyousefi/Fountain](https://github.com/nyousefi/Fountain) (MIT). The rest of the code was written by [Claude Sonnet 4.6](https://claude.ai).

## License

MIT — see [LICENSE](LICENSE).
