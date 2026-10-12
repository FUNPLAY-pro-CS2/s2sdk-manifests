s2sdk-manifests
---------------

What a project needs to build against [s2sdk](https://github.com/alliedmodders/s2sdk) (cs2, dota,
deadlock), for AMBuild and CMake alike. It's the Source 2 counterpart of
[hl2sdk-manifests](https://github.com/alliedmodders/hl2sdk-manifests), which this repository started from.

```
manifests/<game>.json            what differs per game: name, SOURCE_ENGINE code, platforms, env vars
SdkHelpers.ambuild               AMBuild entry point (hl2sdk-manifests' SdkHelpers interface)
s2sdk-manifests.cmake            CMake entry point (s2sdk_manifest(), s2sdk_protobufs())
makefiles/ambuild/shared.ambuild <-> makefiles/cmake/shared.cmake    include paths, defines, C++ standard
makefiles/ambuild/linux.ambuild  <-> makefiles/cmake/linux.cmake     Linux defines and libraries
makefiles/ambuild/windows.ambuild <-> makefiles/cmake/windows.cmake  Windows defines and libraries
makefiles/ambuild/protobufs.ambuild <-> makefiles/cmake/protobufs.cmake  protoc, addProtobufs() / s2sdk_protobufs()
tests/ambuild, tests/cmake       the same small library through each
```

Each `.ambuild` file has a `.cmake` twin with the same lists in the same order, so both build systems
give a binary the same include paths, defines and libraries. A change to what the SDK needs goes into
both twins.

## AMBuild

```python
SdkHelpers = builder.Eval('s2sdk-manifests/SdkHelpers.ambuild')
SdkHelpers.findSdks(builder, cxx_list, ['cs2'])  # find_sdk_path defaults to the manifest's env_vars
for sdk_target in SdkHelpers.sdk_targets:
    SdkHelpers.configureCxx(builder, binary, sdk_target.sdk)
    SdkHelpers.addProtobufs(builder, binary, sdk_target, ['common/netmessages.proto', ...])
```

## CMake

```cmake
include(s2sdk-manifests/s2sdk-manifests.cmake)
s2sdk_manifest(cs2 "$ENV{S2SDK}")                       # s2sdk::headers, s2sdk::s2sdk, ...
s2sdk_manifest(dota "${DOTA_SDK}" PREFIX s2sdk_dota)    # a second SDK in the same build

target_link_libraries(my_plugin PRIVATE s2sdk::s2sdk)
s2sdk_protobufs(my_plugin common/netmessages.proto common/networkbasetypes.proto)
```

| Target | What it has |
|---|---|
| `<prefix>::headers` | include paths, defines (`META_IS_SOURCE2` among them) and C++ standard |
| `<prefix>::tier0`, `::interfaces`, `::mathlib`, `::protobuf`, `::steam_api` | one library each |
| `<prefix>::s2sdk` | all of the above |

With MSVC the SDK's libraries use the static runtime (`/MT`), so set `CMAKE_MSVC_RUNTIME_LIBRARY` to
`MultiThreaded`.

## The std::string / STL ABI

The SDK's libraries use the old `std::string` ABI on Linux (`_GLIBCXX_USE_CXX11_ABI=0`) and no MSVC
iterator debugging (`_ITERATOR_DEBUG_LEVEL=0`). Every library a plugin passes strings or STL types to
has to agree, the vendored ones too, or the plugin loads with undefined symbols.

- CMake: including `s2sdk-manifests.cmake` sets them (and `CMAKE_POSITION_INDEPENDENT_CODE`) for the
  whole directory and the ones added below it, so include it before the project's vendored libraries.
- AMBuild: `configureCxx` sets them for the binary; add `SdkHelpers.abiDefines(cxx)` to the project's
  own libraries that don't go through it.
