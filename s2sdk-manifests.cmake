# CMake entry point:
#
#   include(path/to/s2sdk-manifests/s2sdk-manifests.cmake)
#   s2sdk_manifest(cs2 "$ENV{S2SDK}")                      # s2sdk::headers, s2sdk::s2sdk, ...
#   s2sdk_manifest(dota "${DOTA_SDK}" PREFIX s2sdk_dota)   # a second SDK in the same build
#   target_link_libraries(my_plugin PRIVATE s2sdk::s2sdk)
#   s2sdk_protobufs(my_plugin common/netmessages.proto common/networkbasetypes.proto)
#
# manifests/<game>.json has what differs per game. What a binary needs from the
# SDK is the same for every game and comes from makefiles/cmake/:
# shared.cmake <-> shared.ambuild, linux.cmake <-> linux.ambuild,
# windows.cmake <-> windows.ambuild, protobufs.cmake <-> protobufs.ambuild --
# the CMake twins of makefiles/ambuild/,
# which SdkHelpers.ambuild loads for AMBuild builds.
#
# Targets, under the prefix (s2sdk by default):
#   <prefix>::headers      include paths, defines and C++ standard
#   <prefix>::tier0, ::interfaces, ::mathlib, ::protobuf, ::steam_api  one library each
#   <prefix>::s2sdk        all of the above
# REPLACE <library> <target> ... links a target instead of a prebuilt library,
# for an SDK that builds it from source. The SDK's folder and protoc are the
# INTERFACE_S2SDK_DIR / INTERFACE_S2SDK_PROTOC properties of <prefix>_headers.
#
# Including this file also sets the SDK's std::string / STL ABI defines for the
# whole directory (and the ones added below it), so include it before the
# project's vendored libraries.
#
# With MSVC the SDK's libraries use the static runtime (/MT): set
# CMAKE_MSVC_RUNTIME_LIBRARY to MultiThreaded.

cmake_minimum_required(VERSION 3.19) # string(JSON)

set(S2SDK_MANIFESTS_ROOT "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "s2sdk-manifests root")

include("${CMAKE_CURRENT_LIST_DIR}/makefiles/cmake/shared.cmake")
if(WIN32)
	include("${CMAKE_CURRENT_LIST_DIR}/makefiles/cmake/windows.cmake")
else()
	include("${CMAKE_CURRENT_LIST_DIR}/makefiles/cmake/linux.cmake")
endif()
include("${CMAKE_CURRENT_LIST_DIR}/makefiles/cmake/protobufs.cmake")

# The std::string / STL ABI the SDK's libraries were built with, for every target
# of the directory this is included from and the ones added below it -- vendored
# libraries a plugin passes strings to included. Include this file before them.
add_compile_definitions(${S2SDK_ABI_DEFINES})

function(s2sdk_manifest game sdk_dir)
	cmake_parse_arguments(PARSE_ARGV 2 arg "" "PREFIX" "REPLACE")
	if(NOT arg_PREFIX)
		set(arg_PREFIX s2sdk)
	endif()

	set(manifest "${S2SDK_MANIFESTS_ROOT}/manifests/${game}.json")
	if(NOT EXISTS "${manifest}")
		message(FATAL_ERROR "s2sdk-manifests: no manifest for '${game}'")
	endif()
	set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${manifest}")
	file(READ "${manifest}" json)

	file(TO_CMAKE_PATH "${sdk_dir}" sdk_dir)
	if(NOT EXISTS "${sdk_dir}/public")
		message(FATAL_ERROR "s2sdk-manifests: '${sdk_dir}' is not an s2sdk checkout (${game})")
	endif()
	if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
		message(FATAL_ERROR "s2sdk-manifests: only 64-bit targets are supported")
	endif()
	string(JSON platform_archs ERROR_VARIABLE unsupported GET "${json}" platforms ${S2SDK_PLATFORM})
	if(unsupported)
		message(FATAL_ERROR "s2sdk-manifests: ${game} has no ${S2SDK_PLATFORM} build")
	endif()
	string(JSON code GET "${json}" code)

	# shared.cmake, then the platform's file
	s2sdk_configure_shared(${arg_PREFIX} "${sdk_dir}" ${code})
	s2sdk_configure_platform(${arg_PREFIX} "${sdk_dir}")

	# The libraries the platform's file listed, one target each, named after the
	# file (libtier0.so -> <prefix>::tier0) or the target REPLACE gives for it
	add_library(${arg_PREFIX} INTERFACE)
	add_library(${arg_PREFIX}::s2sdk ALIAS ${arg_PREFIX})
	target_link_libraries(${arg_PREFIX} INTERFACE ${arg_PREFIX}_headers)
	foreach(lib ${S2SDK_LIBS})
		get_filename_component(name "${lib}" NAME_WE)
		string(REGEX REPLACE "^lib|64$" "" name "${name}")
		set(lib "${sdk_dir}/${lib}")
		list(FIND arg_REPLACE ${name} index)
		if(index GREATER -1)
			math(EXPR index "${index} + 1")
			list(GET arg_REPLACE ${index} lib)
		endif()
		add_library(${arg_PREFIX}_${name} INTERFACE)
		add_library(${arg_PREFIX}::${name} ALIAS ${arg_PREFIX}_${name})
		target_link_libraries(${arg_PREFIX}_${name} INTERFACE ${lib})
		target_link_libraries(${arg_PREFIX} INTERFACE ${arg_PREFIX}_${name})
	endforeach()
	target_link_options(${arg_PREFIX} INTERFACE ${S2SDK_LINK_OPTIONS})
endfunction()
