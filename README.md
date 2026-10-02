# RillAIUsage

Standalone Swift extension for Rill, inspired by the side panel in
[CodeNotch](https://github.com/vinzdg/codenotch). It shows Claude, Codex and
Perplexity in a black panel attached to a screen edge, with inverse rounded
corners, white provider logos, colored usage rings and percentage labels.
At rest, the panel folds into a 6-by-48-point black edge handle. Hover it
for 100 ms or press it to reveal the provider rings. Hover or click a provider
to open its black detail card with progress bars and reset times. Moving away
from both panel and card folds it again after 260 ms. Rill owns
the native windows, contour, animation, input and accessibility; this package
owns credentials access, service requests and the three provider readings.

## Build

Keep `RillAIUsage`, `Rill` and optionally `RillNotch` beside each other.
Requires macOS 14+, Swift 6 and the Rill revision containing `edge_widgets`
and the semantic `metric` node. Older Rill builds cannot load this extension.

```sh
./scripts/build.sh
../Rill/scripts/build.sh
../Rill/.build/DerivedData/Build/Products/Debug/Rill.app/Contents/Resources/bin/rillctl validate --config config.toml
swift test
```

## Preview the reference design

```sh
./scripts/preview.sh
```

This launches a separate Rill instance with a temporary runtime and only the
AI panel. The demo explicitly uses the reference values 73%, 21% and 52%.
Quit that instance from its Rill status menu to close the preview. Your normal
Rill configuration is not edited.

`coexistence.toml` demonstrates a top bar, RillNotch and RillAIUsage in one
Rill instance. For a fully synthetic preview, launch Rill with
`RILL_AI_USAGE_DEMO=1` and `RILL_NOTCH_DEMO=1` and that configuration.

## Add to an existing bar and notch

Keep the existing surfaces and notch widgets. Set `schema_version = 2`, then
add these tables with the absolute path to this package:

```toml
[[extensions]]
id = "dev.rill.aiusage"
path = "/absolute/path/to/RillAIUsage"
grant = []

[[edge_widgets]]
id = "ai-usage"
extension = "dev.rill.aiusage"
contribution = "ai-usage"
display = "primary"
edge = "right"
thickness = 64
length = 312
auto_collapse = true
```

`auto_collapse = true` enables the resting handle and hover expansion.
The panel fits its enabled providers: 136 points long for one, 224 for two,
312 for three, capped by `length`. Its default sample width is 64 points,
with 40-point rings and smaller detail cards. Provider changes resize the
visible contour and pointer region on the next update.
Opening follows RillNotch's independent springs, with slower, asymmetric
end movement and progressive content reveal over about 0.8 seconds.
Omitting it preserves a permanently expanded panel. Escape folds an
auto-collapsing panel; its accessible handle can also be pressed to open it.

`edge` accepts `right`, `left`, `bottom` or `top`. On a horizontal edge, use
`thickness = 104` or omit thickness to use its orientation-aware default.
`display = "all"` mirrors the panel with independent hover state per display.
`offset` moves the panel along the edge from the center in AppKit points;
positive offsets move right on horizontal edges and up on vertical edges.
Placement clamps to the visible screen axis. Rill allows one edge widget per
edge/display; put several providers in its contribution, as this package does.
A bar cannot occupy the same edge, and a top widget cannot share a display
with a notch widget. A top bar, centered notch and right widget coexist.

## Live readings

### Choose providers

Create `usage.local.json` in the RillAIUsage package directory. For Claude
and Codex without Perplexity:

```json
{
  "enabled_providers": ["claude", "codex"]
}
```

Use `["codex"]` for Codex alone. Supported names are `claude`, `codex` and
`perplexity`; select at least one, without duplicates. Display order remains
Claude, Codex, Perplexity. Disabled providers are neither fetched nor shown,
including in demo mode and `--check`.

The file is local and Git-ignored; `usage.example.json` lists all three.
Without a local file, all providers remain enabled. Rill reads it from the
extension package directory; run standalone commands from that directory.
Changes apply on the next 60-second refresh. Invalid edits keep the previous
selection and report an error; an invalid file at startup stops the plugin.

### Connect accounts

Run `.build/release/RillAIUsage --check` to print a usage-only diagnostic.
Credentials never appear in this output. Refreshes run every 60 seconds,
respect HTTP rate-limit delays and retain the last good reading with its age
when a service becomes unavailable. Unknown readings show `?`, never a fake
zero. The plugin does not refresh tokens or change existing credentials.

- **Claude:** reads the existing Claude Code `.credentials.json` or login
  keychain item. `CLAUDE_CONFIG_DIR` is supported, including the hashed keychain
  service name. If keychain access needs authorization, run
  `.build/release/RillAIUsage --connect-claude` and approve the macOS prompt.
  Sign in with Claude Code first if no credentials exist. Background polling
  never opens a keychain authorization prompt.
- **Codex:** reads the existing `auth.json` under `CODEX_HOME` or `~/.codex`
  and requests the account session and weekly usage windows. Sign in with
  Codex first if no session is available.
- **Perplexity:** run `.build/release/RillAIUsage --connect-perplexity`, sign
  in in the dedicated WebKit window, then close it. The extension uses that
  WebKit session to query the same-origin rate-limit endpoint. The live
  response supplies remaining counts without a total, so the label reads
  `52 left`, for example, and no percentage arc is invented. The 52% ring is
  only part of the reference demo.

These service response formats follow CodeNotch's implementations at
`72fb2169ef316834ad632f85de27a415cd0d2298`. They are account/web-app usage
endpoints and can change. They do not measure token usage by API key.

## Attribution and verification

The Claude, OpenAI and Perplexity outlines are derived from CodeNotch's
`Sources/Providers/GlyphOutline.swift`. Its MIT notice is preserved in
`ThirdParty/CodeNotch-LICENSE`. `scripts/render-icons.swift` reproduces the
included transparent white PNGs. The screen contour reuses Rill's existing
notch shape; no CodeNotch UI source is loaded into Rill.

See `evidence/verification.md` for the actual local checks and remaining
manual checks. The normal configuration selects live data; demo mode must
be explicitly enabled.
