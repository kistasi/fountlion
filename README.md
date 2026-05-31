# FountLion

A [Fountain](https://fountain.io) screenplay editor for OS X 10.7 Lion.

## Features

- Syntax highlighting with standard screenplay margins (scene headings, action, character, dialogue, parenthetical, transition)
- Character name autocomplete
- Status bar with file path, word/character count, and dark mode toggle
- Light and dark mode
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
