cmake_minimum_required(VERSION 3.12)
project(FORTIS VERSION 1.0.0 LANGUAGES C CXX Fortran)

set(CMAKE_Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

option(FORTIS_BUILD_TESTS "Build test programs" ON)
option(FORTIS_USE_MKL "Use Intel MKL for BLAS" OFF)
option(FORTIS_TORCH_BACKEND "Enable LibTorch backend" ON)
option(FORTIS_BUILD_SHARED "Build shared library" OFF)

find_package(MPI REQUIRED)

if(FORTIS_USE_MKL)
  find_package(MKL REQUIRED)
  set(BLAS_LIBRARIES MKL::MKL)
else()
  find_package(BLAS REQUIRED)
endif()

set(FORTIS_SOURCES
  src/fortis.f90
  src/fortis_blas.f90
  src/fortis_mpi.f90
)

set(FORTIS_C_SOURCES
  csrc/mmap_loader.c
  csrc/shm_utils.c
)

if(FORTIS_TORCH_BACKEND)
  list(APPEND FORTIS_SOURCES src/fortis_torch.f90)
  list(APPEND FORTIS_C_SOURCES csrc/torch_bridge.cpp)
  
  set(CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH};${TORCH_PATH}")
  find_package(Torch REQUIRED)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${TORCH_CXX_FLAGS}")
endif()

add_library(fortis_c_static STATIC ${FORTIS_C_SOURCES})
target_include_directories(fortis_c_static PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/csrc>
  $<INSTALL_INTERFACE:include/fortis>
)
target_link_libraries(fortis_c_static PUBLIC ${CMAKE_DL_LIBS} rt)

if(FORTIS_TORCH_BACKEND)
  target_link_libraries(fortis_c_static PUBLIC "${TORCH_LIBRARIES}")
  target_compile_definitions(fortis_c_static PUBLIC FORTIS_TORCH_ENABLED)
endif()

if(FORTIS_BUILD_SHARED)
  add_library(fortis SHARED ${FORTIS_SOURCES})
  add_library(fortis_static STATIC ${FORTIS_SOURCES})
  set_target_properties(fortis_static PROPERTIES OUTPUT_NAME fortis)
else()
  add_library(fortis STATIC ${FORTIS_SOURCES})
endif()

target_link_libraries(fortis PUBLIC 
  fortis_c_static
  MPI::MPI_Fortran
  ${BLAS_LIBRARIES}
)

if(FORTIS_BUILD_SHARED)
  target_link_libraries(fortis_static PUBLIC 
    fortis_c_static
    MPI::MPI_Fortran
    ${BLAS_LIBRARIES}
  )
endif()

if(CMAKE_Fortran_COMPILER_ID MATCHES "GNU")
  target_compile_options(fortis PRIVATE -O3 -march=native -funroll-loops)
elseif(CMAKE_Fortran_COMPILER_ID MATCHES "Intel")
  target_compile_options(fortis PRIVATE -O3 -xHost -qopt-zmm-usage=high)
endif()

if(FORTIS_BUILD_TESTS)
  enable_testing()
  
  add_executable(test_blas tests/test_blas.f90)
  target_link_libraries(test_blas fortis)
  add_test(NAME blas_test COMMAND test_blas)
  set_tests_properties(blas_test PROPERTIES TIMEOUT 60)
  
  if(FORTIS_TORCH_BACKEND)
    add_executable(test_torch tests/test_torch.f90)
    target_link_libraries(test_torch fortis)
    add_test(NAME torch_test COMMAND test_torch)
    set_tests_properties(torch_test PROPERTIES TIMEOUT 60)
  endif()
  
  add_executable(test_mpi tests/test_mpi.f90)
  target_link_libraries(test_mpi fortis)
  
  if(MPIEXEC_EXECUTABLE)
    add_test(NAME mpi_test_2 
      COMMAND ${MPIEXEC_EXECUTABLE} ${MPIEXEC_NUMPROC_FLAG} 2 
              ${CMAKE_CURRENT_BINARY_DIR}/test_mpi)
    add_test(NAME mpi_test_4 
      COMMAND ${MPIEXEC_EXECUTABLE} ${MPIEXEC_NUMPROC_FLAG} 4 
              ${CMAKE_CURRENT_BINARY_DIR}/test_mpi)
    set_tests_properties(mpi_test_2 mpi_test_4 PROPERTIES TIMEOUT 120)
  endif()
endif()

include(GNUInstallDirs)

install(TARGETS fortis fortis_c_static
  EXPORT FortisTargets
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(FORTIS_BUILD_SHARED)
  install(TARGETS fortis_static
    EXPORT FortisTargets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  )
endif()

install(DIRECTORY ${CMAKE_Fortran_MODULE_DIRECTORY}/
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/fortis
  FILES_MATCHING PATTERN "*.mod"
)

install(FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/csrc/fortis_c.h
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/fortis
)

install(EXPORT FortisTargets
  FILE FortisTargets.cmake
  NAMESPACE Fortis::
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/Fortis
)

include(CMakePackageConfigHelpers)

configure_package_config_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/cmake/FortisConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/FortisConfig.cmake
  INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/Fortis
)

write_basic_package_version_file(
  ${CMAKE_CURRENT_BINARY_DIR}/FortisConfigVersion.cmake
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY SameMajorVersion
)

install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/FortisConfig.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/FortisConfigVersion.cmake
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/Fortis
)

message(STATUS "")
message(STATUS "FORTIS Configuration Summary:")
message(STATUS "  Version: ${PROJECT_VERSION}")
message(STATUS "  Install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "  MPI: ${MPI_Fortran_COMPILER}")
message(STATUS "  MPI Launcher: ${MPIEXEC_EXECUTABLE}")
message(STATUS "  BLAS: ${BLAS_LIBRARIES}")
if(FORTIS_TORCH_BACKEND)
  message(STATUS "  LibTorch: ENABLED")
  message(STATUS "    Path: ${TORCH_LIBRARIES}")
else()
  message(STATUS "  LibTorch: DISABLED")
endif()
message(STATUS "  Build tests: ${FORTIS_BUILD_TESTS}")
message(STATUS "  Build shared: ${FORTIS_BUILD_SHARED}")
message(STATUS "  Fortran compiler: ${CMAKE_Fortran_COMPILER_ID} ${CMAKE_Fortran_COMPILER_VERSION}")
message(STATUS "  Fortran flags: ${CMAKE_Fortran_FLAGS}")
message(STATUS "")