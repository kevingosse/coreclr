project(ryujit)

add_definitions(-DFEATURE_NO_HOST)
add_definitions(-DSELF_NO_HOST)
remove_definitions(-DFEATURE_MERGE_JIT_AND_ENGINE)

if(FEATURE_READYTORUN)
  add_definitions(-DFEATURE_READYTORUN_COMPILER)
endif(FEATURE_READYTORUN)

if(WIN32)
  add_definitions(-DFX_VER_INTERNALNAME_STR=clrjit.dll)
endif(WIN32)

set_source_files_properties(${JIT_EXPORTS_FILE} PROPERTIES GENERATED TRUE)

add_library_clr(clrjit
   SHARED
   ${SHARED_LIB_SOURCES}
   ${JIT_ARCH_SOURCES}
)

target_precompile_header(TARGET clrjit HEADER jitpch.h ADDITIONAL_INCLUDE_DIRECTORIES ${JIT_SOURCE_DIR})

add_dependencies(clrjit jit_exports)

set_property(TARGET clrjit APPEND_STRING PROPERTY LINK_FLAGS ${JIT_EXPORTS_LINKER_OPTION})
set_property(TARGET clrjit APPEND_STRING PROPERTY LINK_DEPENDS ${JIT_EXPORTS_FILE})

target_link_libraries(clrjit
   ${RYUJIT_LINK_LIBRARIES}
)

# add the install targets
install_clr(TARGETS clrjit)
install_clr(TARGETS clrjit DESTINATION sharedFramework)

# Enable profile guided optimization
add_pgo(clrjit)
