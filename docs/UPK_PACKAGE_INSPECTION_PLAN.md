# Plan: RS2 UPK Mesh Inspection

## Goal

Extend UELib so Unreal Engine 3 packages used by Rising Storm 2: Vietnam can
expose skeletal-mesh inspection data, then build a read-only command-line tool
for AircraftMod development. The tool should report mesh, LOD, skeleton, bone,
and socket information in human-readable and machine-readable form so an
AI-assisted code review can compare package transforms with UnrealScript
configuration.

This is a package-inspection tool, not a renderer inside UE Explorer. It will
not modify or save packages, preview animation, or replace the UE3 editor.

## Findings to carry into implementation

- UELib recognizes RS2 package versions `765/771` for script support, but its
  documented model and animation support is incomplete.
- UE Explorer can enumerate the BirdDog mesh's `SkeletalMeshSocket` objects and
  display their `SocketName`, `BoneName`, `RelativeLocation`,
  `RelativeRotation`, and preview assets. The parent mesh's `Sockets` property
  is displayed as an array whose element type was not detected. This suggests
  that individual socket objects are already readable, while the typed array
  relationship and skeletal-mesh native data may need additional support.
- UEViewer's UE3 mesh code is a useful reference. Its `USkeletalMesh3` model
  includes socket references, `RefSkeleton`, LOD data, and version-specific
  serialization. Its socket object carries the socket and bone names plus
  relative transform fields. UEViewer has many game/version branches, so port
  only the needed serialization behavior rather than its renderer or all mesh
  code.
- The raw socket transform is relative to `BoneName`. To derive a mesh-space
  transform, the tool must also read that bone's reference-pose transform and
  hierarchy. Runtime animation can further change the transform and is outside
  the initial static-package inspection scope.
- UEViewer and UELib are MIT-licensed. Preserve UEViewer's copyright and
  license notice in any source materially adapted from it.

## Work plan

### 1. Characterize the RS2 package and UELib representation

- Inspect the provided BirdDog package read-only and record its package,
  licensee, and compression versions before adding format logic.
- Enumerate the `BirdDog_Rig_Master` export, its `Outer`/reference paths, and
  all `SkeletalMeshSocket` exports through UELib's existing object/property
  APIs.
- Determine whether the mesh's `Sockets` array is an ordinary tagged array of
  UObject references or part of the native serialized mesh payload. Confirm
  whether its entries correspond to the visible child socket objects and
  preserve their order.
- Map the existing UELib deserialization hooks and property-array metadata
  conventions. Choose the supported upstream branch rather than assuming the
  substantially refactored `next` branch is the right base.

### 2. Add RS2-first skeletal-mesh data support to UELib

Start with read-only support for the RS2 package layout. Keep version checks
explicit and fail with a useful unsupported-version diagnostic rather than
silently returning partial data.

Initial data surface:

- Skeletal-mesh identity, package reference path, bounds, mesh origin, and
  rotation origin.
- A typed `Sockets` array of UObject references and the socket object's name,
  bone name, relative location, relative rotation, relative scale, and preview
  asset references.
- Reference-skeleton bone names, parent indices, and reference-pose transforms,
  sufficient to compute mesh-space socket transforms.
- Useful LOD summaries: LOD count, vertex/index counts, section/material
  assignments, and bounds where the RS2 serialization exposes them reliably.

Do not initially implement vertex rendering, animation playback, or every
UE3 mesh payload. The goal is to inspect data relevant to transforms and
configuration. Add deeper LOD/geometry decoding only if the initial reports
show it is needed.

Use UEViewer as a format reference for the RS2-compatible UE3 serialization
path, especially its socket array and reference skeleton handling. Translate
the data model into UELib's C# stream/property conventions; do not copy the
entire renderer, archive system, or game-specific branches wholesale.

### 3. Validate against the BirdDog asset

- Compare the parsed socket set against UE Explorer output, including
  `L_Wing`, `L_Aileron`, `RootSocket`, and `ThirdPersonCamera`.
- Verify that each socket's `BoneName` resolves to a reference-skeleton bone.
- Compose bone reference transforms with socket-relative transforms using an
  explicitly documented transform order. Preserve raw UE values alongside
  derived transforms.
- Verify rotator conversion, handedness, axis basis, scale, and UU units using
  known sockets and a second independent viewer/editor result.
- Cross-check the extracted socket names against AircraftMod's
  `AttachmentTargetName` values and report missing or unmatched names.

Do not commit the BirdDog `.upk` or other proprietary game packages as test
fixtures. Use local, user-provided packages for integration tests and add
synthetic or non-copyrighted fixtures for automated parsing tests where
possible.

### 4. Check whether the implementation generalizes

- Test the parser against other UE3 packages that use the same serialized
  skeletal-mesh layout, including another package in the `765/771` family.
- Separate format-common code from RS2-specific version/licensee branches.
- Add another game/version only after verifying its serialization against a
  known-good reader such as UEViewer or UE Explorer.
- Document which fields are supported, which are skipped, and which versions
  have been tested. Genericity is a measured outcome, not an assumption based
  on one RS2 package.

### 5. Build the AircraftMod inspection CLI

Create a small .NET command-line project that uses the extended UELib. It
should accept package paths and selected object names, then emit a readable
summary and JSON suitable for later analysis.

The initial report should include:

- Package identity, version, compression state, and parse warnings.
- Matching skeletal-mesh exports and their object/reference paths.
- LOD summary and mesh bounds.
- Bone hierarchy and reference-pose transforms.
- Socket name, bone, raw relative transform, and derived mesh-space transform.
- A comparison against configured AircraftMod socket names.

Keep the output deterministic and retain raw values so the tool does not hide
unit or transform assumptions. Do not add a 3D viewer to UE Explorer as part
of this work.

### 6. Prepare and submit the UELib pull request

- Keep the parser/library changes separate from the AircraftMod-specific CLI.
- Include automated tests, RS2 version notes, supported-field documentation,
  and clear unsupported-version errors.
- Do not include proprietary package files in the PR.
- Preserve the MIT notices for UEViewer-derived portions and document which
  serialization behavior was adapted.
- Submit the UELib PR after the RS2 tests pass and the implementation has been
  checked against at least one additional compatible package.

## Risks and boundaries

- The parent `Sockets` array may be easy to type from package metadata, while
  `RefSkeleton` and LOD structures require native serialized-data parsing.
  These should be investigated separately so a socket-only requirement does
  not accidentally grow into a full renderer project.
- Mesh/socket reference-pose data does not represent every animated runtime
  pose. If a socket is attached to an animated bone, validate its in-game
  transform separately before changing flight-physics axes.
- UEViewer's serializer contains numerous game and version conditionals.
  Copying its generic-looking path without checking the RS2 build and
  licensee version could produce plausible but incorrect transforms.
- Compressed packages may require a decompression step. Keep source packages
  unchanged and report decompression/parsing failures explicitly.
- This work is read-only. Package editing, mesh rendering, animation playback,
  flight-model changes, and telemetry changes are out of scope.

## Completion criteria

- UELib can identify the BirdDog skeletal mesh and list all associated sockets.
- Socket names, bone names, and relative transforms match UE Explorer for the
  same package.
- The tool resolves socket bones and reports mesh-space transforms from the
  reference skeleton with documented coordinate and unit conventions.
- LOD summaries are accurate for the tested RS2 package.
- Tests establish which parts of the parser are generic to other UE3 packages
  and which are RS2/version-specific.
- The CLI provides deterministic text/JSON reports without modifying package
  files or requiring a renderer.
