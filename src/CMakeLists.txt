file(GLOB LOGTEST_SOURCES CONFIGURE_DEPENDS
    "${PROJECT_SOURCE_DIR}/src/*.cc"
    "${PROJECT_SOURCE_DIR}/src/*.c"
    "${PROJECT_SOURCE_DIR}/src/*.cpp"
)

find_package(ikun_log)


foreach(_source_file IN LISTS LOGTEST_SOURCES)
    set(_name "${_source_file}")
    STRING(REPLACE ".cc" "" _name ${_name})
    STRING(REPLACE "${PROJECT_SOURCE_DIR}/src/" "" _name ${_name})
    add_executable(${_name} ${_source_file})
    target_link_libraries(${_name} PRIVATE
        ikun_log::ikun_log
        spdlog
        benchmark
    )
    add_dependencies(${_name} logtest_third_party_dependencies)
endforeach()

