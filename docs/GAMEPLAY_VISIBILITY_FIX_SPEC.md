# Gameplay Visibility Fix — Camera Bounds + Single Tile Set

Status: SPEC READY / IMPLEMENTATION NOT STARTED

Base / State Snapshot: `8ce815b954034d6cbd290715677d8203b578c54a`

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
