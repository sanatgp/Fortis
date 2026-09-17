add_library(fortis_rt STATIC fortis_rt.c fortis_fft.cu)
set_target_properties(fortis_rt PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(fortis_rt PUBLIC ${CUDAToolkit_INCLUDE_DIRS} ${CUDNN_DIR}/include ${MATH_LIBS_DIR}/include)
install(TARGETS fortis_rt DESTINATION lib)
