# What Windows needs from the SDK -- CMake twin of makefiles/ambuild/windows.ambuild.

set(S2SDK_PLATFORM windows)

set(S2SDK_PLATFORM_DEFINES
	COMPILER_MSVC
	COMPILER_MSVC64
	WIN32
	WIN64
	# The game is built without iterator debugging, which changes the layout of STL
	# types, like the strings in protobuf messages that plugins share with the game
	_ITERATOR_DEBUG_LEVEL=0
)

# What the STL layout depends on: every target of the project has to agree with
# it, the vendored libraries too (s2sdk-manifests.cmake sets it for the whole
# directory it is included from)
set(S2SDK_ABI_DEFINES
	_ITERATOR_DEBUG_LEVEL=0
)

# Built with the static runtime (/MT), so the binary has to be as well
set(S2SDK_LIBS
	lib/public/win64/2015/libprotobuf.lib
	lib/public/win64/mathlib.lib
	lib/public/win64/tier0.lib
	lib/public/win64/interfaces.lib
	lib/public/win64/steam_api64.lib
)

set(S2SDK_LINK_OPTIONS legacy_stdio_definitions.lib)

function(s2sdk_configure_platform prefix sdk_dir)
	target_compile_definitions(${prefix}_headers INTERFACE ${S2SDK_PLATFORM_DEFINES})
	if(MSVC AND NOT CMAKE_MSVC_RUNTIME_LIBRARY MATCHES "^MultiThreaded(\\$<\\$<CONFIG:Debug>:Debug>)?$")
		message(WARNING "s2sdk's libraries use the static runtime (/MT); set CMAKE_MSVC_RUNTIME_LIBRARY to MultiThreaded")
	endif()
endfunction()
