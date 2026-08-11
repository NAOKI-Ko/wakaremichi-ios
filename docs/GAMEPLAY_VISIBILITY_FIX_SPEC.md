# Gameplay Visibility Fix — Camera Bounds + Single Tile Set

Status: FIX REQUIRED / REVIEW FIX SPEC READY

Base / State Snapshot: `d451969ce538a9f7ea6165389da32c17f6d0719c`

Latest reviewed implementation/config commit: `135b101b94704bfa8cdc6911227ef8a5db8cf35a`

This is a v1.0 release-blocking visibility work unit. It does not authorize implementation in the specification-sync commit.

## User QA findings

1. Near map edges—especially the bottom edge—the player, nearby path, or goal can be pushed too close to or outside the useful visible area.
2. Multiple floor and wall texture variants reduce instant recognition of passable and impassable cells.

## Existing implementation investigated

### Scene and viewport

- `MazeScene` starts at `Tuning.viewportTiles * 40` points (currently 520x520).
- `MazeScene.scaleMode` is `.resizeFill`, so SpriteKit resizes the scene to the rectangular `SpriteView` bounds supplied by SwiftUI.
- `MazePlayView` gives `SpriteView` all flexible space between the header and a fixed 112-point HUD.
- The header and HUD are SwiftUI siblings rather than SpriteKit overlays, while an event choice may overlay the complete play view.
- No `didChangeSize(_:)` handling currently reclamps the camera or rebuilds viewport-sized decoration after the SpriteKit view changes size.

### Camera

- `SKCameraNode` follows each normal movement step and warp, and resets at restart.
- `clampedCameraPosition(_:)` uses half of the current scene width/height and the full maze world bounds.
- The clamp keeps the world boundary flush with the visible viewport. The walkable perimeter and goal sit one cell inside the outer wall, leaving the player/goal only about 1.5 tiles from the viewport edge at a map boundary.
- The camera is recalculated during movement and restart, but not in response to a SwiftUI/SpriteKit viewport size change.
- The vignette is created from the scene size once during `didMove(to:)` and is not resized later.

### Working cause hypothesis

The issue is a combined viewport-and-bounds problem rather than a bottom-only coordinate error:

- `.resizeFill` makes the effective tile count depend on the device and the flexible SwiftUI area instead of the initial square scene size.
- The current world-edge clamp guarantees no outside-world exposure, but provides no protected gameplay margin for the player, nearby goal, or next decision cells.
- A later size change can leave camera and camera-attached viewport decoration based on different effective geometry until the next movement update.
- The fixed header/HUD reduce the useful play viewport; fixing only the camera coordinate without validating the SwiftUI crop would be incomplete.

Implementation must verify this hypothesis with actual scene/view sizes before finalizing the fix.

## Camera and viewport requirements

- Follow the player as today in the map interior.
- Near every edge, clamp against a single, testable camera-bounds calculation derived from world size and the effective viewport.
- Preserve a useful on-screen margin for the player and nearby goal/path. A small, controlled background overscan is allowed when required; large outside-world exposure is not.
- Recompute bounds and reclamp immediately when the scene/view size changes.
- Keep camera movement, warp relocation, and restart reset on the same clamp path.
- Update any viewport-sized camera decoration, including the vignette, when the viewport changes.
- Validate the complete SwiftUI `MazePlayView` layout so the header, HUD, safe area, SpriteView frame, and clipping agree with the SpriteKit viewport.
- Do not move the goal or alter maze generation, topology, collision, movement, or Fog of War.

## Planned implementation points

1. Extract a pure camera-bounds/clamp calculation that accepts world size, effective viewport size, target position, and the approved edge-context margin. It must handle viewports larger than an axis of the world without inverted ranges.
2. Use that calculation from initial camera creation, normal movement, warp, restart, and viewport-size changes.
3. Add `didChangeSize(_:)` handling in `MazeScene` to reclamp the current camera and refresh viewport-sized decoration.
4. Inspect the runtime `SKView`/scene size and `MazePlayView` frame on small and standard iPhones. Adjust the SwiftUI container only if it still crops or misreports the SpriteKit viewport.
5. Keep the existing goal coordinate, camera animation timing, HUD height/semantics, and input behavior unless a minimal viewport correction requires otherwise.

## Camera acceptance matrix

Verify all nine positions:

- center
- top, bottom, left, right edges
- top-left, top-right, bottom-left, bottom-right corners

At every position:

- player is visible and not crushed against the screen edge
- adjacent passable path and surrounding wall/floor are readable
- a nearby goal remains visible
- HUD/header do not completely cover important cells
- no unintended large blank region outside the maze is exposed

Minimum viewport QA:

- small iPhone / approximately 320x568 points
- standard iPhone / approximately 390x844 points

Human Gate must cover all four edges and all four corners on a physical device.

## Current tile variant structure

`MazeScene` currently defines three floor textures and three wall textures:

- Floor: `MazeFloor`, `FloorVariantA`, `FloorVariantB`
- Wall: `MazeWall`, `WallVariantA`, `WallVariantB`

`variantIndex(for:count:salt:)` hashes 6x6 chunk coordinates to select one of the three textures. `croppedTexture(from:for:)` then selects a coordinate-dependent region of that texture. Floor and wall tints are applied separately afterward.

This selection is coordinate-deterministic rather than RNG-driven, but it still changes the visible texture across the maze and must be disabled for v1.0.

## v1.0 single tile set

- Floor texture: `MazeFloor`
- Wall texture: `MazeWall`

Rationale:

- `MazeFloor` is the calmest and most even of the floor candidates, with less wall-like block structure and less navigation-disrupting detail.
- `MazeWall` has the clearest masonry silhouette and strongest impassable-cell reading while remaining darker than the floor after the existing tint.
- The A/B floor variants read more like coarse masonry or mossy blocks, while the A/B wall variants contain brighter or more detailed faces that compete with floor and gameplay markers.

Implementation policy:

- Always use `MazeFloor` for floor cells and `MazeWall` for wall cells.
- Remove gameplay use of the texture arrays and `variantIndex` selection.
- Coordinate-based cropping within the selected base texture may remain if it does not undermine cell readability; seed/chunk selection among different source textures must not remain.
- Keep unused variant assets in the catalog for rollback unless they cause a build warning.
- Preserve floor/wall cell classification, tinting pipeline, Fog of War, collision, and topology.
- If the selected pair still lacks sufficient contrast, allow only a minimal adjustment to existing brightness, alpha, color blend, or overlay values. Do not generate new art for this work unit.

## Focused tests for the implementation work unit

Camera geometry:

- horizontal lower and upper bounds
- vertical lower and upper bounds
- all four corner clamps
- viewport-size changes
- viewport larger than a world axis
- returned camera position never falls outside its valid range

Tile selection:

- every floor cell selects `MazeFloor`
- every wall cell selects `MazeWall`
- coordinate and daily seed changes do not change the selected source texture

Existing tests must remain passing. Debug Simulator and Release Generic iOS Device builds are required after implementation.

## Non-goals

- Maze generation or daily seed changes
- Fog of War, movement, auto-slide, stamina, treasure, warp, or goal-coordinate changes
- Diagnosis, DailyRun, streak, collection, Replay, Rewarded ads, Result, audio, or haptics
- SwiftData schema, Bundle ID, App Icon, AdMob, or StoreKit changes
- Asset deletion or new image generation

## Delivery sequence

Implementation → focused and full tests → Debug/Release builds → visual QA → Human Gate → exact SHA review.

## Review Fix — Screen-Space Gameplay Safe Frame

### Audit timeline

- Initial specification sync: `d451969ce538a9f7ea6165389da32c17f6d0719c`
- Initial implementation: `f6a35a3239a9fc307a835a60ff4c2bb24f598cbd`
- Code review: PASS
- Initial Human QA: reported PASS
- Final Review Receipt: `69563123adfe7f39e2a3e56e2716789578b81871`
- Subsequent Human evidence: FAIL — bottom SpriteView/HUD boundary clipping reproduced
- Previous approval: REVOKED / superseded by subsequent physical-device evidence
- Current camera status: FIX REQUIRED
- Floor/wall single-texture status: PASS / retained

The previous receipt remains in Git history. This correction records the later evidence rather than deleting or rewriting the earlier decision.

### Why the previous acceptance was insufficient

The implementation derives camera bounds from world size, runtime viewport size, and symmetric one-tile overscan. Its pure tests prove that the camera position is finite and lies inside those calculated bounds. They do not prove that the final rendered player, goal, or nearby tiles are fully visible inside the actual `SpriteView` after SwiftUI layout and the HUD boundary are applied.

Camera-bounds validity alone must not be used as the acceptance mechanism for the review fix.

### Screen-space gameplay safe frame

The next implementation must define `gameplaySafeRect` inside the actual visible bounds of the runtime `SpriteView`:

1. Read the actual visible SpriteView/SKView viewport.
2. Inset it by explicit horizontal, top, and bottom gameplay safety margins.
3. Use the resulting screen-space rectangle as the visibility acceptance frame.

The bottom margin is visual padding inside the SpriteView. It must not subtract the fixed 112-point HUD a second time. The safe frame must keep gameplay sprites away from the SpriteView/HUD boundary while retaining the existing gameplay scale.

### Sprite bounding-frame acceptance

Acceptance must use complete projected visual bounds rather than tile centers:

- Player frame derived from the actual `playerNode` size and scale
- Goal frame derived from the actual `GoalFlag` sprite size and scale
- Tile size and at least approximately one adjacent cell of decision context
- Additional visual padding where required; glow extent may be considered if it affects readability

After selecting the camera position, convert the relevant world/scene frames into actual view coordinates. At minimum:

```text
playerFrame.minX >= gameplaySafeRect.minX
playerFrame.maxX <= gameplaySafeRect.maxX
playerFrame.minY >= gameplaySafeRect.minY
playerFrame.maxY <= gameplaySafeRect.maxY
```

Apply the same checks to a visible nearby goal. When both the player and an already-discovered nearby goal can fit, choose the smallest camera adjustment that keeps both frames inside the safe rectangle. This must not reveal or track an unexplored distant goal.

### Edge-aware camera behavior

- Center: preserve current player-follow behavior.
- Edges: move the camera only as far outside the world direction as required to bring complete visual frames into the safe rectangle.
- Corners: satisfy horizontal and vertical safety simultaneously.
- Bottom: keep player, nearby goal, and path context clear of the SpriteView/HUD boundary.

Small controlled outside-world reveal remains allowed. Zoom-out, gameplay-scale changes, goal or maze-coordinate changes, a large blank region, and a bottom-only special case remain prohibited.

### Required integration tests

Keep the pure `MazeCameraGeometry` tests and add tests using actual `MazeScene`, `SKView`/`SpriteView` geometry, `playerNode`, and `goalNode` for:

- Bottom-edge player
- Bottom-edge goal
- Bottom-right goal
- Bottom-left
- Top, left, and right edges
- All four corners

These tests must project player/goal visual frames into view coordinates and assert containment in `gameplaySafeRect`; checking only `camera.position` is insufficient.

At least one regression test must render the complete `MazePlayView`, including the header, SpriteView, 112-point HUD, and the visible SpriteView/HUD boundary.

### Required new visual evidence

Do not reuse the previous evidence. Capture at least:

1. Bottom edge
2. Bottom goal
3. Bottom-right goal
4. Bottom-left
5. Top edge
6. Left or right edge
7. One corner
8. Full `MazePlayView` with the HUD boundary

At least one image must show maze tiles, player, goal, SpriteView bottom boundary, and HUD top boundary together so clipping can be judged directly.

### Preserved tile behavior and non-goals

Floor remains `MazeFloor`; wall remains `MazeWall`. Do not restore A/B variants or chunk/hash source selection. Coordinate cropping may remain.

The review fix does not authorize changes to maze generation, seed, topology, movement, auto slide, Fog of War, stamina, treasure, warp, goal coordinates, persistence, diagnosis, Result, Replay, Rewarded ads, audio, haptics, SwiftData, identifiers, App Icon, AdMob, StoreKit, Version, or Build.
