# The CMake side of s2sdk-manifests: reads manifests/<game>.json, the same file
# SdkHelpers.ambuild reads, so a CMake build gets the include paths, defines and
# libraries an AMBuild build of the same project gets.
#
#   include(path/to/s2sdk-manifests/cmake/s2sdk-manifests.cmake)
#   s2sdk_manifest(cs2 "$ENV{S2SDK}")                 # targets s2sdk::headers, s2sdk::s2sdk
#   s2sdk_manifest(dota "${DOTA_SDK}" PREFIX s2sdk_dota)  # a second SDK in the same build
#   target_link_libraries(my_plugin PRIVATE s2sdk::s2sdk)
#   s2sdk_protobufs(my_plugin common/netmessages.proto common/networkbasetypes.proto)
#
# <prefix>::headers has the include paths, defines and C++ standard. Each of the
# SDK's libraries is a target named after its file (<prefix>::tier0,
# ::interfaces, ::mathlib, ::protobuf, ::steam_api), and <prefix>::s2sdk links
# the headers, all of them and the link flags. The SDK's folder and protoc are
# the INTERFACE_S2SDK_DIR / INTERFACE_S2SDK_PROTOC properties of <prefix>_headers.
#
# REPLACE <name> <target> ... links a target instead of a library's prebuilt file,
# for an SDK that builds it from source:
#
#   s2sdk_manifest(cs2 "${S2SDK_DIR}" REPLACE interfaces my_interfaces mathlib my_mathlib)
#
# With MSVC the SDK's libraries use the static runtime (/MT), so the consumer has
# to as well: set CMAKE_MSVC_RUNTIME_LIBRARY to MultiThreaded.

cmake_minimum_required(VERSION 3.19) # string(JSON)

set(S2SDK_MANIFESTS_DIR "${CMAKE_CURRENT_LIST_DIR}/.." CACHE INTERNAL "s2sdk-manifests root")

# The array at the given JSON path as a CMake list, empty when there is none
function(_s2sdk_manifest_list out json)
	string(JSON count ERROR_VARIABLE error LENGTH "${json}" ${ARGN})
	set(result)
	if(NOT error AND count GREATER 0)
		math(EXPR last "${count} - 1")
		foreach(i RANGE ${last})
			string(JSON item GET "${json}" ${ARGN} ${i})
			list(APPEND result "${item}")
		endforeach()
	endif()
	set(${out} "${result}" PARENT_SCOPE)
endfunction()

# A list from the manifest's top level, its platform and its arch, like
# SdkHelpers.getLists
function(_s2sdk_manifest_lists out json platform arch name)
	_s2sdk_manifest_list(top "${json}" ${name})
	_s2sdk_manifest_list(plat "${json}" ${platform} ${name})
	_s2sdk_manifest_list(arch_list "${json}" ${platform} ${arch} ${name})
	set(${out} ${top} ${plat} ${arch_list} PARENT_SCOPE)
endfunction()

function(s2sdk_manifest game sdk_dir)
	cmake_parse_arguments(PARSE_ARGV 2 arg "" "PREFIX" "REPLACE")
	if(NOT arg_PREFIX)
		set(arg_PREFIX s2sdk)
	endif()
	set(prefix ${arg_PREFIX})

	set(manifest "${S2SDK_MANIFESTS_DIR}/manifests/${game}.json")
	if(NOT EXISTS "${manifest}")
		message(FATAL_ERROR "s2sdk-manifests: no manifest for '${game}'")
	endif()
	set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${manifest}")
	file(READ "${manifest}" json)

	file(TO_CMAKE_PATH "${sdk_dir}" sdk_dir)
	if(NOT sdk_dir OR NOT EXISTS "${sdk_dir}/public")
		message(FATAL_ERROR "s2sdk-manifests: '${sdk_dir}' is not an s2sdk checkout (${game})")
	endif()

	if(WIN32)
		set(platform windows)
	else()
		set(platform linux)
	endif()
	if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
		message(FATAL_ERROR "s2sdk-manifests: only 64-bit targets are supported")
	endif()
	set(arch x86_64)

	_s2sdk_manifest_list(archs "${json}" platforms ${platform})
	if(NOT arch IN_LIST archs)
		message(FATAL_ERROR "s2sdk-manifests: ${game} has no ${platform}/${arch} build")
	endif()

	string(JSON code GET "${json}" code)
	string(JSON standard ERROR_VARIABLE no_standard GET "${json}" cxx_standard)
	string(JSON protoc ERROR_VARIABLE no_protoc GET "${json}" ${platform} protoc_path)

	_s2sdk_manifest_list(include_paths "${json}" include_paths)
	list(TRANSFORM include_paths PREPEND "${sdk_dir}/")
	_s2sdk_manifest_lists(defines "${json}" ${platform} ${arch} defines)
	_s2sdk_manifest_lists(cflags "${json}" ${platform} ${arch} cflags)
	_s2sdk_manifest_lists(cxxflags "${json}" ${platform} ${arch} cxxflags)
	_s2sdk_manifest_lists(linkflags "${json}" ${platform} ${arch} linkflags)
	_s2sdk_manifest_lists(libs "${json}" ${platform} ${arch} libs)
	_s2sdk_manifest_lists(postlink_libs "${json}" ${platform} ${arch} postlink_libs)
	_s2sdk_manifest_lists(dynamic_libs "${json}" ${platform} ${arch} dynamic_libs)
	set(all_libs ${libs} ${postlink_libs} ${dynamic_libs})
	list(TRANSFORM all_libs PREPEND "${sdk_dir}/")

	# Includes, defines and language level, without any library
	add_library(${prefix}_headers INTERFACE)
	add_library(${prefix}::headers ALIAS ${prefix}_headers)
	target_include_directories(${prefix}_headers INTERFACE ${include_paths})
	target_compile_definitions(${prefix}_headers INTERFACE SOURCE_ENGINE=${code} ${defines})
	target_compile_options(${prefix}_headers INTERFACE
		$<$<COMPILE_LANGUAGE:C>:${cflags}>
		$<$<COMPILE_LANGUAGE:CXX>:${cxxflags}>
	)
	if(NOT no_standard)
		target_compile_features(${prefix}_headers INTERFACE cxx_std_${standard})
	endif()

	set_target_properties(${prefix}_headers PROPERTIES
		INTERFACE_S2SDK_GAME "${game}"
		INTERFACE_S2SDK_DIR "${sdk_dir}"
	)
	if(NOT no_protoc)
		set_target_properties(${prefix}_headers PROPERTIES INTERFACE_S2SDK_PROTOC "${sdk_dir}/${protoc}")
	endif()

	# One target per library, named after its file (libtier0.so -> <prefix>::tier0,
	# steam_api64.lib -> <prefix>::steam_api), or the target REPLACE gives for it
	set(lib_targets)
	foreach(lib ${all_libs})
		get_filename_component(name "${lib}" NAME_WE)
		string(REGEX REPLACE "^lib" "" name "${name}")
		string(REGEX REPLACE "64$" "" name "${name}")
		list(FIND arg_REPLACE ${name} index)
		if(index GREATER -1)
			math(EXPR index "${index} + 1")
			list(GET arg_REPLACE ${index} lib)
		endif()
		add_library(${prefix}_${name} INTERFACE)
		add_library(${prefix}::${name} ALIAS ${prefix}_${name})
		target_link_libraries(${prefix}_${name} INTERFACE ${lib})
		list(APPEND lib_targets ${prefix}_${name})
	endforeach()

	# Everything: the headers, the SDK's libraries and its link flags
	add_library(${prefix} INTERFACE)
	add_library(${prefix}::s2sdk ALIAS ${prefix})
	target_link_libraries(${prefix} INTERFACE ${prefix}_headers ${lib_targets})
	target_link_options(${prefix} INTERFACE ${linkflags})
endfunction()

# Generates the given protos into a target and compiles them with it, like
# AMBuild's Protoc tool with SdkTarget.protoc. The protos are relative to the
# SDK or absolute, and a proto's imports have to be listed too. Imports are
# looked up in each proto's folder, then the SDK's include paths. The generated
# headers' folder is public, for a static library of protobufs. SDK names the
# prefix given to s2sdk_manifest() (default s2sdk).
#
#   s2sdk_protobufs(my_plugin [SDK s2sdk_dota] common/netmessages.proto ...)
function(s2sdk_protobufs target)
	cmake_parse_arguments(PARSE_ARGV 1 arg "" "SDK" "")
	if(NOT arg_SDK)
		set(arg_SDK s2sdk)
	endif()
	get_target_property(sdk_dir ${arg_SDK}_headers INTERFACE_S2SDK_DIR)
	get_target_property(protoc ${arg_SDK}_headers INTERFACE_S2SDK_PROTOC)
	get_target_property(includes ${arg_SDK}_headers INTERFACE_INCLUDE_DIRECTORIES)
	if(NOT protoc)
		message(FATAL_ERROR "s2sdk-manifests: ${arg_SDK} has no protoc for this platform")
	endif()

	set(out "${CMAKE_CURRENT_BINARY_DIR}/${target}_protobufs")
	file(MAKE_DIRECTORY "${out}")

	set(protos)
	set(dirs)
	foreach(proto ${arg_UNPARSED_ARGUMENTS})
		if(NOT IS_ABSOLUTE "${proto}")
			set(proto "${sdk_dir}/${proto}")
		endif()
		get_filename_component(dir "${proto}" DIRECTORY)
		list(APPEND protos "${proto}")
		list(APPEND dirs "${dir}")
	endforeach()
	list(APPEND dirs ${includes})

	# One protoc run per proto with its own folder first, like the Protoc tool: a
	# proto in a subfolder of another one's folder would otherwise be seen under
	# two names when one imports it.
	set(sources)
	foreach(proto ${protos})
		get_filename_component(dir "${proto}" DIRECTORY)
		get_filename_component(name "${proto}" NAME_WE)
		set(proto_paths "${dir}" ${dirs})
		list(REMOVE_DUPLICATES proto_paths)
		list(TRANSFORM proto_paths PREPEND "--proto_path=")
		add_custom_command(
			OUTPUT "${out}/${name}.pb.cc" "${out}/${name}.pb.h"
			COMMAND "${protoc}" ${proto_paths} "--cpp_out=${out}" "${proto}"
			DEPENDS ${protos}
			COMMENT "Generating ${name}.pb.cc"
			VERBATIM
		)
		list(APPEND sources "${out}/${name}.pb.cc")
	endforeach()

	target_sources(${target} PRIVATE ${sources})
	target_include_directories(${target} PUBLIC "${out}")
endfunction()
