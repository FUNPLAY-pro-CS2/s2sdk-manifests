# Builds a small plugin-like library against an s2sdk checkout through the CMake
# module, to check that the manifest's include paths, defines, libraries and
# protobufs work:
#
#   cmake -S tests/cmake -B build -G Ninja -DGAME=cs2 -DS2SDK_DIR=/path/to/s2sdk
#   cmake --build build
cmake_minimum_required(VERSION 3.19)
project(s2sdk_manifests_test CXX)

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

if(NOT GAME)
	set(GAME cs2)
endif()
if(NOT S2SDK_DIR)
	set(S2SDK_DIR "$ENV{S2SDK}")
endif()

include(${CMAKE_CURRENT_SOURCE_DIR}/../../s2sdk-manifests.cmake)
s2sdk_manifest(${GAME} "${S2SDK_DIR}")

add_library(s2sdk_manifests_test SHARED main.cpp)
target_link_libraries(s2sdk_manifests_test PRIVATE s2sdk::s2sdk)
s2sdk_protobufs(s2sdk_manifests_test common/valveextensions.proto common/network_connection.proto common/networkbasetypes.proto)
