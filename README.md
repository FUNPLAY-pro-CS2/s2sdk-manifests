s2sdk-manifests
---------------

What a project needs to build against [s2sdk](https://github.com/alliedmodders/s2sdk) (the Source 2
SDKs: cs2, dota, deadlock), in one place for both AMBuild and CMake. It's the Source 2 counterpart of
[hl2sdk-manifests](https://github.com/alliedmodders/hl2sdk-manifests), and this repository started as a
copy of it.

```
manifests/<game>.json        include paths, defines, libraries, protoc, C++ standard, platforms
SdkHelpers.ambuild           AMBuild: same interface as hl2sdk-manifests' SdkHelpers
cmake/s2sdk-manifests.cmake  CMake: s2sdk_manifest() targets and s2sdk_protobufs()
tests/cmake                  builds a small library through the CMake module
```

Both build systems read the same manifest, so an AMBuild build and a CMake build of a project get
the same include paths, defines and libraries. A change to what the SDK needs (a moved header folder,
a new library) is made once, in the manifest.

## Manifests

Every list (`defines`, `cflags`, `cxxflags`, `linkflags`, `libs`, `postlink_libs`, `dynamic_libs`)
can be at the top level, in the platform (`linux`, `windows`) or in the platform's arch (`x86_64`).
The top level applies everywhere and the arch level is the most specific. Library paths are
relative to the SDK.

- `libs` are linked by path.
- `postlink_libs` come after the binary's own objects.
- `dynamic_libs` are shared libraries the binary loads at runtime (`libtier0.so`, `libsteam_api.so`).
  AMBuild links them by file name from the binary's folder.

`SOURCE_ENGINE=<code>` is defined from `code`. `env_vars` are the variables the SDK's path is read
from, in order.

## AMBuild

```python
SdkHelpers = builder.Eval('s2sdk-manifests/SdkHelpers.ambuild')
SdkHelpers.findSdks(builder, cxx_list, ['cs2'])   # find_sdk_path defaults to the manifest's env_vars
for sdk_target in SdkHelpers.sdk_targets:
    binary = ...
    SdkHelpers.configureCxx(builder, binary, sdk_target.sdk)
    # sdk_target.protoc: protoc set up with the SDK's include paths
```

## CMake

```cmake
include(s2sdk-manifests/cmake/s2sdk-manifests.cmake)
s2sdk_manifest(cs2 "$ENV{S2SDK}")                          # s2sdk::headers, s2sdk::s2sdk, ...
s2sdk_manifest(dota "${DOTA_SDK}" PREFIX s2sdk_dota)       # a second SDK in the same build

target_link_libraries(my_plugin PRIVATE s2sdk::s2sdk)
s2sdk_protobufs(my_plugin common/netmessages.proto common/networkbasetypes.proto)
```

The module creates these targets:

| Target | What it has |
|---|---|
| `<prefix>::headers` | include paths, defines and C++ standard |
| `<prefix>::tier0`, `::interfaces`, `::mathlib`, `::protobuf`, `::steam_api` | one library each |
| `<prefix>::s2sdk` | all of the above and the link flags |

With MSVC the SDK's prebuilt libraries use the static runtime (`/MT`), so set
`CMAKE_MSVC_RUNTIME_LIBRARY` to `MultiThreaded`.
