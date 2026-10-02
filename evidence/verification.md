# Local verification, 2026-10-02

Environment: macOS 27, Xcode/Swift 6, Apple Silicon arm64; one external
2560x1080 scale-1 display with no physical notch reported during these checks.

| Check | Result | Evidence |
| --- | --- | --- |
| Rill build | PASS | `../Rill/scripts/build.sh`, `/tmp/rillaiusage-host-build.log` |
| Rill tests | PASS | 122 core/platform/configuration tests and 9 IPC tests, `/tmp/rillaiusage-host-tests.log` |
| Final edge placement/routing/configuration checks | PASS | 5 focused tests after final contour/card adjustments, `/tmp/rillaiusage-edge-tests.log` |
| SDK tests | PASS | 7 tests, `/tmp/rillaiusage-sdk-tests.log` |
| RillAIUsage release build | PASS | `./scripts/build.sh`, `/tmp/rillaiusage-plugin-build.log` |
| RillAIUsage tests | PASS | 7 tests, `/tmp/rillaiusage-plugin-tests.log` |
| Framed executable handshake/update/shutdown | PASS | `protocol.json`: hello, 73/21/52 metric update, clean shutdown exit 0 |
| Standalone and coexistence config validation | PASS | `rillctl validate --config config.toml` and `coexistence.toml` |
| Compact native rendering | PASS | `compact/report.json`, `compact/top-display-1.png`: one visible non-key/non-main panel, demo logos/rings/labels inspected |
| Native reference preview with backdrop | PASS | `preview/top-display-1.png`: contour, pointer, logos, rings, labels and card inspected against the reference |
| Expanded native detail rendering | PASS | `details/report.json`, `details/top-display-1.png`: Debug fixture explicitly selects the first card; labels, bars and resets inspected |
| Single-instance bar/notch/side coexistence | PASS | `coexistence/report.json`: three visible non-key/non-main panels, app inactive |
| Live Codex account usage | PASS | `--check` returned session and weekly readings; output contains no credentials |
| Missing Claude and Perplexity authorization | PASS | `--check` displays sign-in required with empty windows and unknown percentages |
| Real Claude usage / keychain approval | NOT RUN | No keychain authorization was granted during background checks |
| Real Perplexity login / live quotas | NOT RUN | Dedicated WebKit login requires the owner to sign in |
| Actual pointer hover/click/card departure | NOT VERIFIED | Synthetic pointer injection did not open the card in the automated snapshot; geometry routing tests pass, native mouse observation still required |
| VoiceOver, keyboard traversal, fullscreen, Spaces, sleep/wake and pacing | NOT RUN | Requires manual desktop observation |
| Multiple displays and physical notch fit | NOT RUN | Only one external display was available |

`RILL_AI_USAGE_DEMO=1` is required for the reference percentages. The normal
config uses live providers. The Debug-only `--edge-details-smoke` selects a
card for deterministic native screenshots; `--edge-preview-background` adds
a gradient under the native view to make the transparent contour inspectable.
Neither fixture is enabled in normal use or compiled into Release behavior.

Endpoint/reference source: CodeNotch commit
`72fb2169ef316834ad632f85de27a415cd0d2298`. The Perplexity live response supplies
remaining counts rather than percentages. No fake denominator is applied.
No user configuration, tokens or existing credential files were changed.
No commit or push was performed.

A separate live demo preview is left running through `scripts/preview.sh`.
`preview-runtime.json` reports generation 1, extension ready and no
configuration error. Quit its Rill status menu to close it.

2026-10-02 combined-preview correction: the owner only saw RillAIUsage because
the launched preview intentionally used the standalone configuration. Stopped
that isolated preview and launched one Rill process using a temporary copy of
the normal user configuration with RillAIUsage added on the right for all
displays. Status reports RillNotch, RillAIUsage, Hello and OmniWM ready, no
configuration error, and diagnostics reports three visible panels. The AI
readings still use the explicit demo; RillNotch and normal bar providers remain
live. Process PID: 48452. Temporary config, runtime and PID paths are recorded
in `/tmp/rillaiusage-combined-config-path`,
`/tmp/rillaiusage-combined-runtime-path` and
`/tmp/rillaiusage-combined-preview-pid`. The normal user configuration was not
edited. This combined process replaces the previously documented standalone
preview. Physical appearance still awaits owner observation.

2026-10-02 RillAIUsage resting handle: owner confirmed the combined preview
visually and requested a small black idle handle that expands on hover. Added
opt-in `auto_collapse` to edge widget configuration. RillAIUsage samples and
the owner-authorized temporary combined preview enable it. Idle geometry is
6 by 48 points, attached to the same edge/center; hover opens after 100 ms and
leaving panel plus detail folds it after 260 ms. Accessible press opens, Escape
folds, interrupted hover cancels correctly, and Reduce Motion suppresses the
transition. Content is clipped to the animated contour inside a stationary
canvas. Transparent areas retain click pass-through.

Rill build and 127 core/platform/configuration plus 9 IPC tests PASS. New
regressions cover all-edge handle geometry, hover/departure, brief hover,
reentry, persistent-widget compatibility and config opt-in. Native resting
and expanded render fixtures were inspected under
`RillAIUsage/evidence/collapsed/` and `evidence/expanded/`. The combined preview
is relaunched as PID 54309 with three visible panels, both extensions ready
and no configuration error; `evidence/collapse-runtime.json` records health.
The owner still needs to observe the new real-pointer expansion and motion.
Phase 13 remains IN PROGRESS; existing manual/release gates remain open.

2026-10-02 RillAIUsage organic expansion: owner approved the resting handle
and requested slower, less symmetric movement based on RillNotch. The host
now uses independent keyframe springs for both axial ends and inward depth,
with 0.68/0.78/0.70-second opening tracks, slight elastic follow-through and
progressive masked content reveal. Closing uses separate smooth tracks.
Initial persistent widgets remain fully open; Reduce Motion renders the
settled target directly inside the stationary canvas.

PASS: Debug build and 128 core/platform/configuration plus 9 IPC tests
(`/tmp/rillaiusage-organic-build.log`, `/tmp/rillaiusage-organic-tests.log`).
The added geometry regression covers asymmetric center movement, edge
attachment through negative/overshoot samples and exact resting/open frames
on all four edges. Native resting/open snapshots were inspected in
`RillAIUsage/evidence/organic-collapsed/` and `evidence/organic-expanded/`.
The combined preview was relaunched as PID 33153; `organic-runtime.json`
reports three visible panels, both extensions and providers ready, and no
configuration error. Owner observation of this new motion and dedicated
Reduce Motion/accessibility/frame-pacing checks remain pending. Phase 13
stays IN PROGRESS; existing release gates remain open.

2026-10-02 opening-animation correction: owner reported slow closing but
nearly instant opening. A native NSHostingView bitmap regression reproduced
the opening jump: the contour already had its final rendered length at
100 ms, 250 ms and 950 ms. KeyframeAnimator's initial value had followed the
changing expanded target. It now depends only on the configuration's initial
state (or the explicit Debug preview fixture), preserving the animation's
starting point across interaction updates.

PASS: the regression now observes increasing intermediate rendered lengths,
including a selection update during opening and another gradual opening after
collapse. It skips when the system enables Reduce Motion. Full app suite:
129 core/platform/configuration and 9 IPC tests PASS; Debug build PASS
(`/tmp/rillaiusage-opening-regression-before.log`,
`/tmp/rillaiusage-opening-regression-after.log`,
`/tmp/rillaiusage-opening-tests.log`, `/tmp/rillaiusage-opening-build.log`).
Combined preview relaunched as PID 5183 with three visible panels, ready
extensions and no configuration error; `opening-fix-runtime.json` records
health. Owner assessment of the corrected motion remains pending. Phase 13
stays IN PROGRESS and the existing manual/release gates stay open.

2026-10-02 live-preview correction: owner screenshot still showed Codex's
21% session and 12% weekly demo values. Earlier --check results were live,
but the visible combined process still inherited RILL_AI_USAGE_DEMO=1.
Stopped that tracked process and relaunched the same temporary combined
configuration without the demo environment variable. Future relaunches of
this combined preview must preserve live mode; it is recorded in
/tmp/rillaiusage-combined-preview-mode.

PASS: independent live --check returned Codex 95% session and 42% weekly;
Claude and Perplexity still require sign-in. A native combined live rendering
fixture visibly shows Codex 95% and unknown values for unconnected providers
(evidence/live-combined/top-display-3.png). The normal live preview is left
running as PID 42793. Its diagnostics report three visible panels, ready
extensions/providers and no configuration error, recorded in
live-combined/runtime.json. The render fixture reports PASS in
live-combined/report.json. Refresh scheduling remains 60 seconds after each
collection. No code or user configuration changed. Claude/Perplexity login,
manual motion/accessibility and existing release gates remain open.

2026-10-02 configurable providers: owner requested disabling unused services,
particularly Perplexity. RillAIUsage now reads the Git-ignored package-local
usage.local.json with enabled_providers. Missing file preserves all three;
valid selections contain at least one supported provider without duplicates,
in canonical display order. Only enabled providers are fetched and published.
Demo and --check also honor the selection. The file is re-read each collection;
invalid live edits retain the last valid selection, while invalid startup
settings fail explicitly. Account connection commands remain available.

Owner's local selection is Claude and Codex; Perplexity is disabled. Added
usage.example.json and authoring instructions. PASS: sibling release build and
11 tests covering provider selection, Codex-only mode, validation, on-disk
reload, default compatibility and existing parsing/protocol behavior
(`/tmp/rillaiusage-provider-selection-build.log`,
`/tmp/rillaiusage-provider-selection-tests.log`). Framed subprocess evidence
provider-selection-reload.json confirms the same running process changed from
two providers to Codex alone at the next collection (63.7 seconds).
Independent live --check lists only Claude and Codex; Claude needs sign-in,
Codex has 0% on its newly reset session and 42% weekly. Native live snapshot
provider-selection/top-display-3.png was inspected and shows exactly two
providers. Combined live preview relaunched as PID 45397, with three visible
panels and all extensions/providers ready; provider-selection/runtime.json
and report.json record runtime/render PASS. No host code, normal user config,
credentials, commits or pushes changed. Phase 13 stays IN PROGRESS; existing
manual/release gates remain open.

2026-10-02 compact content-fitting panel: owner reported that disabling
Perplexity left the full-sized container and requested smaller elements.
Metric edge panels now fit their published metric count: 24-point end
padding plus 88-point slots, capped by the configured maximum length.
One/two/three providers yield 136/224/312 points. Shared geometry is used by
rendering, clipping, slot placement and pointer routing on all four edges;
center/edge attachment and the stationary canvas remain stable. Provider
changes clear the old detail selection and its pointer region. Non-metric
content retains its configured size.

Reduced gauges from 48 to 40 points, glyphs from 28 to 24, percentage text
from 18 to 14, and gauge spacing from 12 to 8. Detail cards use 260-point
width instead of 290, smaller title/icon/padding/row gaps and matching pointer
alignment. RillAIUsage samples and the authorized temporary combined preview
now use 64-point thickness and 312-point maximum length. The owner's two
providers therefore occupy 64 by 224 points instead of 80 by 400; local
provider settings still disable Perplexity.

PASS: Debug build and 131 core/platform/configuration plus 9 IPC tests
(`/tmp/rillaiusage-compact-build.log`, `/tmp/rillaiusage-compact-tests.log`).
New geometry tests cover all-edge count fitting, bounds, center/attachment
and pointer selection; a native rendered-frame regression confirms shrinking
from three to two to one providers without closing and clears stale details.
Existing opening/reopening rendering regression still passes. Both sibling
configs validate. Inspected native deterministic demo detail renders in
compact-1-providers/, compact-2-providers/ and compact-3-providers/ under
RillAIUsage/evidence; each report.json records PASS. Demo fixtures used
isolated temporary packages and did not change the owner's live selection.
Combined live preview relaunched as PID 18013 with three visible panels,
ready extensions/providers and no configuration error, recorded in
compact-runtime.json. No credentials or normal user configuration changed.
No commit or push. Owner compactness/actual pointer approval and dedicated
accessibility/pacing gates remain pending; phase 13 stays IN PROGRESS.

2026-10-02 owner acceptance and commit preparation: owner approved the compact
adaptive layout and explicitly requested commits. The host implementation is
committed in Rill as e237e0a (adaptive metric edge widgets and organic hover
expansion). Sibling release build and 11 tests remain PASS; host build and
140 tests PASS. RillAIUsage's first commit includes sources, resource logos,
MIT attribution, examples, authoring documentation and this verification log.
Generated JSON/screenshot evidence and personal usage.local.json remain local
and ignored. The combined preview remains live with Claude/Codex, no
Perplexity, and three healthy panels. No push requested or performed. Owner
approval covers the visible compact design; dedicated accessibility,
physical-notch/multi-display and measured performance gates remain open.
