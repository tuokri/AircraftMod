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

- Once the local package path is supplied, inspect BirdDog read-only and record
  its package, licensee, and compression versions before adding format logic.
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

Create the tool in `tools\upk-inspector` in this repository. Add UELib as a
Git submodule under `tools\upk-inspector\vendor\Unreal-Library` and reference
its source project while both codebases are under active development. This
lets the CLI exercise the exact UELib parser changes in the same checkout
without moving the tool into UE Explorer or waiting for the UELib PR to merge.
The CLI should accept package paths and selected object names, then emit a
readable summary and JSON suitable for later analysis.

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

Example socket record, using values from the UE Explorer output shared during
planning:

```json
{
  "meshPath": "BirdDog.Mesh.BirdDog_Rig_Master",
  "objectPath": "BirdDog.Mesh.BirdDog_Rig_Master.SkeletalMeshSocket_1",
  "socketName": "L_Wing",
  "boneName": "us_birddog_recon",
  "relativeLocationUU": [0.0, -80.0, 50.0],
  "relativeRotationRaw": null,
  "relativeRotationResolved": [0, 0, 0],
  "relativeScaleRaw": null,
  "relativeScaleResolved": [1.0, 1.0, 1.0],
  "meshSpaceTransform": null
}
```

Keep `meshSpaceTransform` absent or `null` until the reference-bone transform
and composition order are implemented and validated. Preserve the raw
rotator values because converting them to degrees is a presentation choice,
not a replacement for the source data. Report whether a field was explicitly
serialized or supplied by the class default; do not make a defaulted value
look like a package-authored value.

### 6. Prepare and submit the UELib pull request

- Keep the UELib parser changes in the submodule repository and the
  AircraftMod-specific CLI in `tools\upk-inspector`.
- Develop the parser on a feature branch in a writable UELib fork, with the
  official UELib repository as the `upstream` remote. Push the parser commits
  and open a separate PR to UELib; the AircraftMod repository records the
  tested UELib commit as its submodule gitlink.
- Include automated tests, RS2 version notes, supported-field documentation,
  and clear unsupported-version errors in the UELib PR.
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

## Detailed implementation blueprint

The following is a more detailed implementation map for an agent starting from
a fresh checkout. It is intentionally read-only until the user supplies the
local package path and the parser spike confirms which bytes UELib currently
handles.

### Upstream API and repository layout

Use the stable UELib default branch as the initial PR base, subject to
maintainer confirmation. Relevant current-master files:

| File | What to learn from it |
|---|---|
| `README.md` | `UnrealLoader` usage, package initialization, object indices, and current game support |
| `src\Core\Classes\Props\UArrayProperty.cs` | How `InnerProperty` is read and retained |
| `src\Core\Classes\UObject.cs` | Object loading, property-tag access, and package object lifecycle |
| `src\Engine\Classes\UPrimitive.cs` | Example of a registered class with a native serialized tail |
| `src\Engine\Classes\UPrimitiveComponent.cs` | UE3 build registration and version-gated tail parsing |
| `src\Engine\Classes\UMeshComponent.cs` | Current mesh-component stubs; these are not mesh-asset parsers |
| `Test\UnrealPackageTests.cs` | MSTest patterns for loading objects and checking property tags |
| `Test\UnrealPackageUtilities.cs` | Existing temporary-package stream helper |
| `Test\Eliot.UELib.Test.csproj` | Test dependencies and target framework |
| `Directory.Build.props` | Supported library target frameworks and analyzer settings |

`UArrayProperty.Deserialize()` reads its `InnerProperty` as a `UProperty`
object reference. Therefore, the first code investigation should inspect the
BirdDog mesh's actual `UArrayProperty.InnerProperty`, not infer its contents
from UE Explorer's rendered `/* Array type was not detected. */` label. The
socket exports and their tagged properties may already be readable even if
the parent array's element type or membership is not.

The `master` branch targets `netstandard2.0`, `netstandard2.1`, and `net10.0`;
the test project targets `net10.0`. The `next` branch has an API/stream
refactor, so do not mix its `[UnrealProperty]`/stream-record patterns into a
`master` PR without first checking which branch the maintainers want.

### UEViewer structures to translate selectively

Relevant UEViewer source files:

- [`Unreal/UnrealMesh/UnMesh3.h`](https://github.com/gildor2/UEViewer/blob/master/Unreal/UnrealMesh/UnMesh3.h)
- [`Unreal/UnrealMesh/UnMesh3.cpp`](https://github.com/gildor2/UEViewer/blob/master/Unreal/UnrealMesh/UnMesh3.cpp)
- [`Unreal/UnObject.cpp`](https://github.com/gildor2/UEViewer/blob/master/Unreal/UnObject.cpp)
- [UEViewer MIT license](https://github.com/gildor2/UEViewer/blob/master/LICENSE.txt)

The UEViewer header provides these useful structural facts:

- `USkeletalMesh3` is represented as an object with bounds, LOD information,
  socket references, mesh origin/rotation origin, a reference skeleton, and
  LOD models.
- `Sockets` is a `TArray<USkeletalMeshSocket*>`; its property table declares
  the entries as UObject references.
- `USkeletalMeshSocket` contains `SocketName`, `BoneName`, `RelativeLocation`,
  `RelativeRotation`, and `RelativeScale`.
- A reference-skeleton bone contains a name, reference pose, and parent index.

The UEViewer serializer calls the UObject serialization path (not the
`UPrimitive` path for its common UE3 skeletal mesh), then reads native fields
including bounds, materials, origin/rotation origin, reference skeleton, and
LOD models. Several games add or reorder fields behind version/licensee
conditions. The BirdDog parser must establish the exact RS2 path before
implementing a native-tail reader. Do not copy offsets from
`Unreal/UnObject.cpp`; that file has format-specific fallback offsets for
property display, not a substitute for parsing the package's property tags.

### Proposed UELib types and responsibilities

Treat the following as responsibilities, not a requirement to use these exact
class names:

1. **Socket object:** register/identify `USkeletalMeshSocket` as a UE3 UObject.
   First rely on generic tagged-property parsing for its fields; add custom
   native parsing only if the BirdDog export contains a non-tagged socket tail.
2. **Socket array:** expose the `USkeletalMesh.Sockets` array as references to
   socket objects. Preserve element order and null entries if the format
   allows them. If `InnerProperty` is absent, determine whether the
   `USkeletalMesh` class schema needs an explicit array-type declaration.
3. **Reference skeleton:** add a typed native structure for each bone with
   stable index, name, parent index, and reference pose. Validate parent
   indices and reject cycles/out-of-range links rather than inventing a
   transform.
4. **Mesh summary:** expose bounds, mesh origin/rotation origin, and the LOD
   summary fields needed by inspection. Full vertex/index/skin-weight
   decompression is a later scope.
5. **Version dispatch:** select the RS2 parser only for the verified package
   and licensee version. Put any layout differences behind explicit guards
   or a small version-specific serializer; do not silently parse unknown
   versions with the RS2 layout.

Current-master class pattern, for orientation only:

```csharp
using UELib.Branch;
using UELib.Core;

[UnrealRegisterClass]
[BuildGeneration(BuildGeneration.UE3)]
public sealed class USkeletalMeshSocket : UObject
{
    // Keep using UObject's tagged-property path unless a fixture proves that
    // this object's RS2 export contains additional native serialized data.
}
```

For a native mesh-tail parser, follow current-master's `Deserialize()` pattern
(`base.Deserialize()`, then `_Buffer` reads and `Record(...)`) and the
`IUnrealStream`/`UArray<T>` helpers already present in the target branch. This
is a design sketch, not compile-ready code: first confirm the exact base class
and serialization order for RS2. UEViewer's common UE3 path uses `UObject`;
blindly deriving from UELib's `UPrimitive` would read extra bounds/sphere data
that may not be present in the skeletal-mesh stream.

### UELib package-inspection spike

Before adding `USkeletalMesh` serialization, write a small console spike that
loads BirdDog read-only, initializes the package, and enumerates exports by
class and outer path. The following follows UELib README/test APIs; confirm
exact nullability in the checked-out revision:

```csharp
using System.IO;
using UELib;

using var package = UnrealLoader.LoadPackage(packagePath, FileAccess.Read);
package.InitializePackage();

foreach (var obj in package.Objects)
{
    if ((int)obj <= 0) // Imports and fake objects have non-positive indices.
    {
        continue;
    }

    if (obj.Class?.Name != "SkeletalMeshSocket")
    {
        continue;
    }

    obj.Load();
    Console.WriteLine(obj.GetReferencePath());
    Console.WriteLine($"Outer: {obj.Outer}");

    var socketName = obj.Properties?.Find("SocketName")?.DeserializeValue();
    var boneName = obj.Properties?.Find("BoneName")?.DeserializeValue();
    Console.WriteLine($"Socket={socketName}, Bone={boneName}");
}
```

This determines whether a separate mesh reader is needed merely to find
sockets. If all socket exports are discoverable and their `Outer` paths point
to `BirdDog_Rig_Master`, the array decoder is only needed to prove membership
and preserve order. Do not parse the text printed by UE Explorer; inspect
UELib's `UObject`, `UProperty`, `UArrayProperty.InnerProperty`, and object
references directly.

### Coordinate and transform representation

Keep the output in two layers:

1. **Raw package values:** `FName` text/index as available, integer FRotator
   components, FVector components, scale, bone index/name, parent index, and
   the original package path.
2. **Derived values:** reference-bone transform, socket mesh-space transform,
   and axes in the coordinate convention used by the AircraftMod code.

The conceptual composition is:

```text
BoneMeshTransform   = ParentBoneMeshTransform * BoneReferenceLocalTransform
SocketMeshTransform = BoneMeshTransform * SocketRelativeTransform
SocketWorldTransform = MeshWorldTransform * SocketMeshTransform
```

The multiplication order and rotator/quaternion conversion must be verified
against UE3/UEViewer output and a known package example. The socket data shown
in UE Explorer is bone-relative; a tool must not label it as mesh-world data.
If the socket is attached to a bone animated in-game, static package data only
describes the reference pose. Runtime validation requires UE3/editor evidence.

Do not assume `RelativeLocation` is meters: keep it in package UU until the
package/engine scale is verified. Preserve raw FRotator units (UE rotator units
are not degrees) and derive degrees/quaternions only as additional fields.

### Test and build workflow

Run the UELib baseline before changes and after each parser milestone:

```powershell
dotnet test .\Test\Eliot.UELib.Test.csproj
dotnet build .\src\Eliot.UELib.sln
```

Use the existing test project and helpers rather than adding a second test
framework. A candidate test matrix:

| Test | Expected result |
|---|---|
| Generic object enumeration | Exports are distinguished from imports/fake objects |
| BirdDog socket export probe | All visible socket objects have stable paths and properties |
| Socket array | `Sockets` inner type, order, references, and null behavior are explicit |
| Bone resolution | Every socket bone resolves or produces a path/index-specific diagnostic |
| Reference skeleton | Root and parent indices form a valid hierarchy |
| Transform composition | Known socket/bone transforms match the independent viewer/editor |
| LOD summary | Counts/bounds/material sections match the package or UEViewer |
| Version guard | Unsupported UE3/licensee variants fail clearly, not with partial data |

The actual BirdDog package is a local integration-test input, not a PR
fixture. Use UELib's synthetic/temp-package helpers or small
non-proprietary fixtures for automated tests. If the binary package is
compressed, record the original hash and inspect a decompressed copy; never
modify the source asset.

### Scope ladder

- **Package/socket inventory:** enumerate mesh exports and socket objects,
  group by `Outer` path, and print tagged socket properties. This may need no
  skeletal-mesh native-tail parser.
- **Socket-array support:** resolve the mesh's `Sockets` array, typed
  references, and ordering. This is the smallest likely UELib feature PR if
  only the inner-property metadata is missing.
- **Mesh-space socket transforms:** parse the RS2 reference skeleton and
  compose bone reference transforms with socket-relative transforms. This is
  the first stage that requires skeletal-mesh native serialization.
- **Useful LOD inspection:** parse LOD counts, bounds, sections, and material
  references; skip or safely consume unneeded bulk buffers.
- **Full mesh/animation support:** decode vertex/index buffers, skin weights,
  all LOD structures, and animation data across UE3 variants. This is a much
  larger project and is not required for the initial AircraftMod tool.

### CLI contract and example output

The CLI should have no rendering dependency. A practical first interface is:

```text
upk-inspector inspect <package.upk> [--object <reference-path>] [--json]
upk-inspector compare-sockets <package.upk> --names <socket-names.txt>
```

Example JSON fragment for a socket shown in the shared UE Explorer output:

```json
{
  "meshPath": "BirdDog.Mesh.BirdDog_Rig_Master",
  "socketName": "L_Wing",
  "boneName": "us_birddog_recon",
  "relativeLocationUU": [0.0, -80.0, 50.0],
  "relativeRotationRaw": null,
  "relativeRotationResolved": [0, 0, 0],
  "relativeScaleRaw": null,
  "relativeScaleResolved": [1.0, 1.0, 1.0],
  "boneReferenceTransform": null,
  "meshSpaceTransform": null,
  "warnings": ["Reference skeleton not yet parsed"]
}
```

Null derived transforms and explicit warnings are preferable to guessed
identity transforms. Once reference bones parse, the CLI should fill the
derived fields without dropping the raw values. Report whether a transform
field was explicitly serialized or supplied by the class default; do not make
a defaulted value look like a package-authored value.

### UELib PR scope and contribution checklist

- Confirm the target branch and preferred design with UELib maintainers before
  large changes. Current `master` is the safer starting point; `next` has a
  major API/stream refactor and an unsupported `UStaticMesh` stub.
- Keep parser source/tests in the UELib submodule and CLI source in
  `tools\upk-inspector`. The CLI should reference the submodule project while
  the parser PR is in progress, then keep using a pinned UELib commit after
  the PR is merged.
- Include a compatibility note for RS2 versions `765/771`, tested
  licensee/platform variants, compression expectations, supported fields, and
  fields intentionally skipped.
- Preserve MIT notices for UEViewer-derived portions. Do not copy the full
  viewer/renderer or its game-specific code paths that are irrelevant to RS2.
- Do not add BirdDog or other commercial `.upk` binaries, extracted meshes, or
  copyrighted textures to the UELib PR.
- Before submission, run all existing UELib tests plus the new tests, inspect
  the diff for unrelated files, and verify that an unsupported package version
  produces an explicit diagnostic.

## Repository onboarding and API quick-start

This section is intended to let an agent start work without reconstructing the
repository and upstream-library context from conversation history.

### Repositories and source map

**AircraftMod**

- `Classes\AMAircraft_O1BirdDog_Content.uc`: declares the BirdDog's surface
  components, `AttachmentTargetName` values, and the active
  `AeroSurfaceComponents` array.
- `Classes\AMVehicleAircraft.uc`: attaches surfaces, consumes their cached
  forces, and draws diagnostic arrows.
- `Classes\AeroSurfaceComponent.uc`: owns the per-surface aerodynamic frame
  and calculations.
- `docs\FLIGHT_MODEL_IMPLEMENTATION_PLAN.md`: records the physics, units,
  axes, and controlled-validation requirements that package inspection should
  support.
- `tools\build\README.md`: shows the repository's existing .NET helper layout
  and build conventions; it is not a dependency of the package parser.

The inspection tool belongs in this repository at
`tools\upk-inspector\`. Its UELib submodule should live at
`tools\upk-inspector\vendor\Unreal-Library\`, with the CLI project referencing
`vendor\Unreal-Library\src\Eliot.UELib.csproj`. Target .NET 10 for the CLI and
the current UELib test project so both can be developed and run together.

Keep the two Git histories distinct:

- The nested UELib repository owns parser source, tests, and its upstream PR.
- The AircraftMod repository owns the CLI and a pinned submodule commit.
- The parent repo never stages or commits files from inside the submodule as
  ordinary files; it records only the submodule commit pointer.
- BirdDog packages remain local integration-test inputs and are not added to
  either repository.

The planned project reference in
`tools\upk-inspector\UpkInspector.csproj` is:

```xml
<ItemGroup>
  <ProjectReference Include="vendor\Unreal-Library\src\Eliot.UELib.csproj" />
</ItemGroup>
```

For initial setup, add a writable UELib fork as the submodule and retain the
official repository as a separate remote inside that submodule:

```powershell
git submodule add https://github.com/<owner>/Unreal-Library.git `
  tools/upk-inspector/vendor/Unreal-Library
git -C .\tools\upk-inspector\vendor\Unreal-Library remote add upstream `
  https://github.com/EliotVU/Unreal-Library.git
git -C .\tools\upk-inspector\vendor\Unreal-Library fetch upstream
git -C .\tools\upk-inspector\vendor\Unreal-Library switch -c `
  feature/rs2-skeletal-mesh upstream/master
```

Replace `<owner>` with the writable fork owner. Push the feature branch from
inside the submodule before committing its gitlink in AircraftMod. This ensures
the parent repository never points at a UELib commit that exists only in a
local clone.

**UELib**

- Repository: <https://github.com/EliotVU/Unreal-Library>
- README and UE3/RS2 support table:
  <https://github.com/EliotVU/Unreal-Library/blob/master/README.md>
- `src\Core\Classes\Props\UArrayProperty.cs`: current master resolves an
  array's `InnerProperty` from a property object reference. Inspect why the
  BirdDog `Sockets` array's inner type is missing before adding a second
  low-level array decoder.
- `src\Engine\Classes\UPrimitive.cs` and
  `src\Engine\Classes\UPrimitiveComponent.cs`: examples of current-master
  registered UE classes and native-tail deserialization.
- `src\Engine\Classes\UMeshComponent.cs`: currently registers empty mesh
  component stubs; it is not a skeletal-mesh asset parser.
- `Test\UnrealPackageTests.cs` and `Test\UnrealPackageUtilities.cs`: existing
  package/type/property test patterns.
- `Test\Eliot.UELib.Test.csproj`: MSTest project targeting .NET 10.
- `Directory.Build.props`: library target frameworks and analyzer/style
  settings.

As checked on 2026-11-18, `master` is the default branch. The `next` branch is
a substantial stream/API refactor and has a `UStaticMesh` stub that explicitly
states mesh deserialization is not implemented. No skeletal-mesh or socket
parser was found in the inspected `master`, `develop`, or `next` branches.
Use the branch maintainers intend for contributions; do not base this work on
`next` merely because it contains newer-looking serialization abstractions.
The current-master `UMeshComponent.cs` contains an empty
`USkeletalMeshComponent` stub, not an asset parser. The UELib README lists
RS2 package versions `765/771` as script-supported but leaves model and
animation support unchecked.

**UEViewer / UModel**

- Repository: <https://github.com/gildor2/UEViewer>
- UE3 skeletal mesh and socket declarations:
  <https://github.com/gildor2/UEViewer/blob/master/Unreal/UnrealMesh/UnMesh3.h>
- UE3 mesh serialization and socket post-load handling:
  <https://github.com/gildor2/UEViewer/blob/master/Unreal/UnrealMesh/UnMesh3.cpp>
- Socket property offset fallback:
  <https://github.com/gildor2/UEViewer/blob/master/Unreal/UnObject.cpp>
- License: <https://github.com/gildor2/UEViewer/blob/master/LICENSE.txt>

UEViewer's `USkeletalMesh3` model includes `Sockets`,
`RefSkeleton`, `LODInfo`, and `LODModels`; its socket structure includes
`SocketName`, `BoneName`, `RelativeLocation`, `RelativeRotation`, and
`RelativeScale`. The socket array is declared as UObject references in its
property table. Its native serializer reads mesh bounds, materials, origin
and rotation origin, reference skeleton, LOD data, and additional
version/game-specific fields. UEViewer is MIT-licensed, as is UELib; retain
the UEViewer copyright/license notice when materially adapting code.

### Start with a baseline and a package probe

Initialize the nested repository and record both repository revisions before
making parser changes. Keep the existing AircraftMod UnrealScript edits
untouched:

```powershell
git submodule update --init --recursive
git -C .\tools\upk-inspector\vendor\Unreal-Library status --short --branch
dotnet test .\tools\upk-inspector\vendor\Unreal-Library\Test\Eliot.UELib.Test.csproj
dotnet build .\tools\upk-inspector\vendor\Unreal-Library\src\Eliot.UELib.sln
```

For simultaneous development, create a feature branch inside the submodule
from the agreed UELib base branch, push it to a writable fork, and add the
official repository as `upstream`. Do not point the parent submodule URL at an
unpublished local commit; the gitlink must refer to a commit available from
the configured submodule remote.

Obtain the local path to `BirdDog.upk` before writing integration tests.
First use the existing package loader to record the summary/version,
compression flags, exports, imports, and object paths. UE3 production
packages may be compressed; test whether the current loader handles this
package before adding a separate decompressor step. Never overwrite or
recompress the original package.

A first read-only exploration program can follow the existing UELib API:

```csharp
using System.IO;
using UELib;

using var package = UnrealLoader.LoadPackage(packagePath, FileAccess.Read);
package.InitializePackage();

foreach (var obj in package.Objects)
{
    // Package.Objects can include imports/fake objects as well as exports.
    if ((int)obj <= 0 || obj.Class?.Name != "SkeletalMeshSocket")
    {
        continue;
    }

    obj.Load();
    Console.WriteLine(obj.GetReferencePath());
    Console.WriteLine($"Outer: {obj.Outer}");
    Console.WriteLine($"Properties: {obj.Properties}");
}
```

This is an exploration sketch, not the finished CLI. The upstream README
documents `UnrealLoader.LoadPackage`, `InitializePackage`, object indices,
class names, outer references, and `GetReferencePath`. Existing tests use
`obj.Properties.Find(name)` and `tag.DeserializeValue()` to inspect property
tags. Prefer typed UELib values for the final report; use rendered property
strings only to diagnose what UE Explorer is showing.

The initial probe should answer four questions before any mesh parser is
written:

1. Are socket objects positive-index exports or are some imported/fake objects?
2. Does each socket's `Outer`/reference path identify
   `BirdDog_Rig_Master`?
3. Does the mesh's `Sockets` tag resolve to a `UArrayProperty` with an
   `InnerProperty`? If not, is the inner type missing, unsupported, or stored
   in native serialization?
4. Can UELib already read the socket's tagged properties without a custom
   socket deserializer?

If enumerating socket exports gives the complete array and outer relationships,
the first CLI may not need a custom `Sockets` decoder at all. If it finds orphan
socket objects or loses array order/membership, add the narrowest typed-array
support that recovers that relationship.

For a one-off property-tag probe, UELib's current tests use
`Properties.Find()` and `DeserializeValue()`:

```csharp
var socketNameTag = obj.Properties?.Find("SocketName");
var socketNameText = socketNameTag?.DeserializeValue();
Console.WriteLine(socketNameText);
```

Treat this as diagnostic output. The CLI's final model should retain typed
names, vectors, and rotators instead of parsing these display strings.

### UELib implementation shape

Use the current target branch's patterns, not snippets copied from UELib's
`next` branch. In current master, registered UE3 classes use
`[UnrealRegisterClass]` and, where needed, `[BuildGeneration(BuildGeneration.UE3)]`.
Native fields are read in `Deserialize()` after `base.Deserialize()` using
UELib stream helpers such as `_Buffer.ReadStruct`, `_Buffer.ReadArray`, and
`Record`.

A class-registration sketch for socket identity is:

```csharp
using UELib.Branch;
using UELib.Core;

[UnrealRegisterClass]
[BuildGeneration(BuildGeneration.UE3)]
public sealed class USkeletalMeshSocket : UObject
{
    // First determine whether generic UObject property tags already provide
    // the socket fields. Add native deserialization only if the package shows
    // a non-tagged serialized tail.
}
```

Do not add duplicate storage for fields that UELib's generic property system
already exposes. UEViewer treats the socket data as object properties and
registers the socket class separately.

The mesh's native payload should be implemented as a separate version-aware
reader. UEViewer's common UE3 path derives its skeletal mesh from `UObject`,
not `UPrimitive`; verify the RS2 serialization base and order before choosing
UELib's base class. Do not assume inheriting UELib's `UPrimitive` is correct
just because both classes have bounds.

For the first useful skeleton representation, retain:

```text
Bone: index, FName, parent index, reference position, reference orientation,
      reference scale if serialized
Socket: object path, socket name, BoneName, relative location/rotation/scale
```

Compute a mesh-space transform by composing the reference-pose transform of
the socket's bone with the socket-relative transform. Document and test the
matrix/quaternion multiplication order; do not infer it from field names.
Keep UE3-native values (UU and raw rotator units) alongside any converted
degrees, vectors, or matrices.

For LODs, first target reliable summaries (LOD count, vertex/index counts,
sections, material references, bounds). Parsing/decompressing all vertex,
index, skin-weight, cloth, and bulk-data buffers is a separate scope. If
native serialization must pass through fields not yet supported to reach the
reference skeleton or LOD summary, implement version-correct skipping only
when the serialized size is known; never guess offsets.

### Test design and commands

Follow the current MSTest patterns in `Test\UnrealPackageTests.cs`:

- Test a minimal synthetic package or isolated serialization helper for a
  `Sockets` array with zero, one, and multiple object references.
- Test `USkeletalMeshSocket` property decoding for names, bone names, vectors,
  rotators, and optional scale/preview fields.
- Test reference-skeleton parent resolution, root bones, invalid indices,
  and socket-to-mesh transform composition.
- Test an unsupported package version produces a clear error rather than
  returning plausible partial data.
- If practical, use `UnrealPackageUtilities.CreateTempPackageStream()` for
  package-structure tests. Do not add `BirdDog.upk` to `Test\Packages.resx` or
  to the PR.
- Run the existing suite plus the new tests with
  `dotnet test .\Test\Eliot.UELib.Test.csproj`.

Use the local BirdDog package for an integration check outside committed
tests. Compare socket names/fields against UE Explorer's output and check
that every `AttachmentTargetName` used by AircraftMod has a matching socket.
UEViewer can provide an independent comparison for the skeletal mesh and
reference skeleton. Record the tested package version and hash locally, but do
not check in the game asset.

### CLI interface sketch

Keep the CLI code in `tools\upk-inspector`, consume UELib through the submodule
project reference, and make the tool read-only. A first command shape could
be:

```text
upk-inspector inspect <package.upk> [--object <reference-path>] [--json]
upk-inspector compare-sockets <package.upk> --names <socket-names.txt>
```

The text and JSON reports should include:

- package path (as supplied), version/licensee version, compression status,
  and parser warnings;
- mesh export path/class, bounds, origin/rotation origin, and LOD summaries;
- bones in stable index order with parent indices and raw reference transforms;
- sockets in package order with object path, socket/bone names, and raw
  relative transform;
- a separately labelled derived mesh-space transform and the conventions used
  to compute it;
- unmatched AircraftMod socket names and unresolved bone/object references.

Never silently substitute zero for an unsupported or unreadable field. Emit a
warning with the object path and serialized field, and keep raw package values
available for debugging. Do not add a 3D rendering dependency.

During development, build and run the tool from the AircraftMod repository
root:

```powershell
dotnet build .\tools\upk-inspector\UpkInspector.csproj
dotnet run --project .\tools\upk-inspector\UpkInspector.csproj -- `
  inspect <path-to-BirdDog.upk> --json
```

### Upstream contribution and PR candidate

Before implementing, check the current upstream contribution guidance and ask
maintainers which branch to target if it is unclear. The `next` branch contains
a major stream/API refactor; its `UStaticMesh` type is still marked as a stub.
Keep the PR on the intended supported branch unless maintainers request
otherwise.

The first PR candidate should contain:

1. a minimal RS2-compatible skeletal-mesh/socket parser with explicit
   version/licensee guards;
2. typed socket-array membership and reference-skeleton data where verified;
3. unit tests that do not redistribute proprietary game packages;
4. documentation describing supported UE3 layouts, fields intentionally
   skipped, and known limitations;
5. preserved MIT notices for any adapted UEViewer logic.

Keep the AircraftMod CLI in this repository under `tools\upk-inspector`; do
not create a separate companion repository for the initial tool. Its project
reference should point to the UELib submodule while the parser PR is in
progress. When the UELib changes are committed and pushed, update the parent
repository's submodule pointer to that commit so the CLI and parser revisions
remain reproducible together.
