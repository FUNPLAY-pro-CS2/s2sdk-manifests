# What every platform needs from the SDK -- CMake twin of makefiles/ambuild/shared.ambuild.
# The per-platform part is in linux.cmake / windows.cmake.

# The same list, in the same order, as shared.ambuild's.
set(S2SDK_INCLUDE_PATHS
	thirdparty/protobuf-3.21.8/src
	public
	public/mathlib
	public/tier0
	public/tier1
	public/entity2
	game/shared
	common
)

set(S2SDK_DEFINES
	GAME_DLL
	RAD_TELEMETRY_DISABLED
	X64BITS
	PLATFORM_64BITS
)

set(S2SDK_CXX_STANDARD 20)

# <prefix>::headers: include paths, defines and C++ standard, without any library
function(s2sdk_configure_shared prefix sdk_dir code)
	set(includes ${S2SDK_INCLUDE_PATHS})
	list(TRANSFORM includes PREPEND "${sdk_dir}/")

	add_library(${prefix}_headers INTERFACE)
	add_library(${prefix}::headers ALIAS ${prefix}_headers)
	target_include_directories(${prefix}_headers INTERFACE ${includes})
	target_compile_definitions(${prefix}_headers INTERFACE SOURCE_ENGINE=${code} ${S2SDK_DEFINES})
	target_compile_features(${prefix}_headers INTERFACE cxx_std_${S2SDK_CXX_STANDARD})
	set_target_properties(${prefix}_headers PROPERTIES
		INTERFACE_S2SDK_DIR "${sdk_dir}"
		INTERFACE_S2SDK_PROTOC "${sdk_dir}/${S2SDK_PROTOC}"
	)
endfunction()
