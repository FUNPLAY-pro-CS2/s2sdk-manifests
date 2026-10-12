# What Linux needs from the SDK -- CMake twin of makefiles/ambuild/linux.ambuild.

set(S2SDK_PLATFORM linux)

set(S2SDK_PLATFORM_DEFINES
	COMPILER_GCC
	_LINUX
	LINUX
	POSIX
	GNUC
	# libprotobuf.a and tier0 use the old std::string ABI
	_GLIBCXX_USE_CXX11_ABI=0
	_finite=finite
	stricmp=strcasecmp
	_stricmp=strcasecmp
	strnicmp=strncasecmp
	_strnicmp=strncasecmp
	strcmpi=strcasecmp
	_vsnprintf=vsnprintf
	_alloca=alloca
)

# linux.ambuild's static libraries, then its shared ones (loaded at runtime)
# What the std::string / STL layout depends on: every target of the project has
# to agree with it, the vendored libraries too (s2sdk-manifests.cmake sets it
# for the whole directory it is included from)
set(S2SDK_ABI_DEFINES
	_GLIBCXX_USE_CXX11_ABI=0
)

set(S2SDK_LIBS
	lib/linux64/mathlib.a
	lib/linux64/interfaces.a
	lib/linux64/release/libprotobuf.a
	lib/linux64/libtier0.so
	lib/linux64/libsteam_api.so
)

set(S2SDK_LINK_OPTIONS -lm)

function(s2sdk_configure_platform prefix sdk_dir)
	target_compile_definitions(${prefix}_headers INTERFACE ${S2SDK_PLATFORM_DEFINES})
endfunction()
