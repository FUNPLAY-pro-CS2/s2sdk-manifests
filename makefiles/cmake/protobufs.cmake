# The SDK's protoc and protobufs -- CMake twin of makefiles/ambuild/protobufs.ambuild.

# protoc runs on the host, which can differ from the target
if(CMAKE_HOST_WIN32)
	set(S2SDK_PROTOC devtools/bin/protoc.exe)
else()
	set(S2SDK_PROTOC devtools/bin/linux/protoc)
endif()

# s2sdk_protobufs(), like SdkHelpers.addProtobufs():
# Generates the given protos into a target and compiles them with it. The protos
# are relative to the SDK or absolute, and a proto's imports have to be listed
# too. Imports are looked up in each proto's folder, then the SDK's include
# paths. The generated headers' folder is public, for a static library of
# protobufs. SDK is the prefix given to s2sdk_manifest() (s2sdk by default).
#
#   s2sdk_protobufs(my_plugin [SDK s2sdk_dota] common/netmessages.proto ...)
function(s2sdk_protobufs target)
	cmake_parse_arguments(PARSE_ARGV 1 arg "" "SDK" "")
	if(NOT arg_SDK)
		set(arg_SDK s2sdk)
	endif()
	if(NOT TARGET ${arg_SDK}_headers)
		message(FATAL_ERROR "s2sdk_protobufs: no SDK was added with the prefix ${arg_SDK}")
	endif()
	get_target_property(sdk_dir ${arg_SDK}_headers INTERFACE_S2SDK_DIR)
	get_target_property(protoc ${arg_SDK}_headers INTERFACE_S2SDK_PROTOC)
	get_target_property(includes ${arg_SDK}_headers INTERFACE_INCLUDE_DIRECTORIES)

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
