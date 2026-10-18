if(NOT DEFINED LOGTEST_DEPS_STAMP_FILE OR NOT DEFINED LOGTEST_DEPS_STAMP_VALUE)
    message(FATAL_ERROR "Dependency stamp file and value are required")
endif()

get_filename_component(stamp_directory "${LOGTEST_DEPS_STAMP_FILE}" DIRECTORY)
file(MAKE_DIRECTORY "${stamp_directory}")
file(WRITE "${LOGTEST_DEPS_STAMP_FILE}" "${LOGTEST_DEPS_STAMP_VALUE}\n")