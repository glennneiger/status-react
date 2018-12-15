if(APPLE)
  set(SCRIPT CompleteBundleOSX)
elseif(WIN32)
  set(SCRIPT CompleteBundleWin)
elseif(UNIX)
  set(SCRIPT CompleteBundleLinux)
endif(APPLE)

if(SCRIPT AND EXISTS ${CMAKE_SOURCE_DIR}/CMakeModules/${SCRIPT}.cmake.in)
  configure_file(${CMAKE_SOURCE_DIR}/CMakeModules/${SCRIPT}.cmake.in ${SCRIPT}.cmake @ONLY)
  include(${CMAKE_CURRENT_BINARY_DIR}/${SCRIPT}.cmake)
endif()
