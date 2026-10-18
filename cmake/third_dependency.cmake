set(LOGTEST_THIRD_PARTY_DIR "${PROJECT_SOURCE_DIR}/third_party" CACHE PATH "Directory containing third-party sources")
set(LOGTEST_THIRD_PARTY_OUT_DIR "${LOGTEST_THIRD_PARTY_DIR}/output" CACHE PATH "Directory containing third-party sources")
set(LOGTEST_THIRD_PARTY_BUILD_TYPE Release CACHE STRING "")
set_property(CACHE LOGTEST_THIRD_PARTY_BUILD_TYPE PROPERTY STRINGS Debug Release RelWithDebInfo MinSizeRel)

option(LOGTEST_UPDATE_SUBMODULES "" on)
option(LOGTEST_REUSE_INSTALLED_DEPENDENCIES "" on)

set(_logtest_required_submodules
    "${PROJECT_SOURCE_DIR}/third_party/benchmark|CMakeLists.txt" 
    "${PROJECT_SOURCE_DIR}/third_party/spdlog|CMakeLists.txt"
)
find_package(Git QUIET)

function(logtest_init_third_party_submodules)
    set(_missing_submodules)
    foreach(entry IN LISTS _logtest_required_submodules)
        string(REPLACE "|" ";" parts "${entry}")
        list(GET parts 0 submodule_path)
        list(GET parts 1 sentinel)
        if(NOT EXISTS "${submodule_path}/${sentinel}")
            list(APPEND  _missing_submodules "${submodule_path}")
        endif()
    endforeach()

    if(NOT _missing_submodules)
        return()
    endif()

    if(NOT LOGTEST_UPDATE_SUBMODULES)
        return()
    endif()

    if(NOT Git_FOUND)
        message(FATAL_ERROR "Git is required to initialize missing submodules.")
    endif()
    
    message(STATUS "Initializing missing git submodules: ${missing_submodules}")
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" submodule update --init --recursive  -- ${_missing_submodules}
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
        RESULT_VARIABLE submodule_result
        OUTPUT_VARIABLE submodule_output
        ERROR_VARIABLE submodule_error
    )

    if(NOT submodule_result EQUAL 0)
        message(FATAL_ERROR
            "git submodule update ${_missing_submodules} failed (exit=${submodule_result}):\n"
            "${submodule_output}${submodule_error}")
    endif()

    foreach(entry IN LISTS _logtest_required_submodules)
        string(REPLACE "|" ";" parts "${entry}")
        list(GET parts 0 submodule_path)
        list(GET parts 1 sentinel)
        if(NOT EXISTS "${submodule_path}/${sentinel}")
           message(FATAL_ERROR "required submodules ${submodule_path} is not exist")
        endif()
    endforeach()
endfunction()

logtest_init_third_party_submodules()

function(logtest_get_source_revision source_dir output_variable)
    if(GIT_FOUND AND EXISTS "${source_dir}/.git")
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" -C "${SOURCE_DIR}" rev-parse HEAD
            WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
            RESULT_VARIABLE revision_result
            OUTPUT_VARIABLE revision_output
            ERROR_VARIABLE revision_error
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        if(NOT revision_result EQUAL 0)
            message(FATAL_ERROR "not get revison submodule ${source_dir}/.git file")
        endif()
    else()
        message(FATAL_ERROR "not found submodule ${source_dir}/.git file")
    endif()
    set(${output_variable} "${revision_output}" PARENT_SCOPE)
endfunction()

function(logtest_add_cmake_dependency)
    cmake_parse_arguments(PARSE_ARGV 0 dep ""
     "NAME;SOURCE_DIR;SOURCE_REVISION"
     "CMAKE_ARGS;SENTINELS;DEPENDS;KEY_MATERIAL")

     if(NOT dep_NAME OR NOT dep_SOURCE_DIR OR NOT dep_SOURCE_REVISION OR NOT dep_SENTINELS)
        message(FATAL_ERROR "function(logtest_add_cmake_dependency) some arg (dep_NAME AND dep_SOURCE_DIR AND SOURCE_REVISION AND SENTINELS) is not exist")
    endif()

    string(CONCAT cache_material 
        "${dep_SOURCE_REVISION};${dep_SOURCE_DIR};${dep_NAME};${CMAKE_C_STANDARD};${CMAKE_C_COMPILER};${CMAKE_C_COMPILER_ID};${CMAKE_C_COMPILER_VERSION};"
        "${CMAKE_CXX_STANDARD};${CMAKE_CXX_COMPILER};${CMAKE_CXX_COMPILER_ID};${CMAKE_CXX_COMPILER_VERSION};${CMAKE_SYSTEM_NAME};${CMAKE_SYSTEM_PROCESSOR};"
        "${CMAKE_GENERATOR};${CMAKE_GENERATOR_PLATFORM};${CMAKE_GENERATOR_TOOLSET};${CMAKE_OSX_ARCHITECTURES};${CMAKE_OSX_DEPLOYMENT_TARGET};static"
        "${CMAKE_MSVC_RUNTIME_LIBRARY};${LOGTEST_THIRD_PARTY_BUILD_TYPE};${dep_CMAKE_ARGS};${dep_KEY_MATERIAL}")

    string(SHA256 cache_key "${cache_material}")
    string(SUBSTRING  "${cache_key}" 0 16 cache_key_short)

    set(install_dir "${LOGTEST_THIRD_PARTY_OUT_DIR}/${dep_NAME}/${cache_key_short}")
    set(build_dir "${LOGTEST_THIRD_PARTY_OUT_DIR}/build/${dep_NAME}/${cache_key_short}")
    set(cache_stamp "${install_dir}/.logtest-cache-${cache_key}")

    set(installed_outputs "${cache_stamp}")
    set(cache_complete TRUE)

    foreach(sentinel IN LISTS dep_SENTINELS)
        if(IS_ABSOLUTE "${sentinel}")
            set(sentinel_path "${sentinel}")
        else()
            set(sentinel_path "${install_dir}/${sentinel}")
        endif()
        list(APPEND installed_outputs "${sentinel_path}")
        if(NOT EXISTS "${sentinel_path}")
            set(cache_complete FALSE)
        endif()
    endforeach()

    if(NOT EXISTS ${cache_stamp})
        set(cache_complete FALSE)
    endif()

    set(configure_command "${CMAKE_COMMAND}" -B "${build_dir}" -S "${dep_SOURCE_DIR}" -G "${CMAKE_GENERATOR}")
    if(EXISTS CMAKE_GENERATOR_PLATFORM)
        list(APPEND  configure_command -A "${CMAKE_GENERATOR_PLATFORM}")
    endif()
    if(EXISTS CMAKE_GENERATOR_TOOLSET)
        list(APPEND configure_command -T "${CMAKE_GENERATOR_TOOLSET}")
    endif()

    list(APPEND configure_command 
        "-DCMAKE_INSTALL_PREFIX=${install_dir}"
        "-DCMAKE_INSTALL_LIBDIR=lib"
        "-DCMAKE_BUILD_TYPE=${LOGTEST_THIRD_PARTY_BUILD_TYPE}"
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
        "-DBUILD_TESTING=OFF"
    )

    
    if(CMAKE_C_COMPILER)
        list(APPEND configure_command "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}")
    endif()
    if(CMAKE_CXX_COMPILER)
        list(APPEND configure_command "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
    endif()
    if(CMAKE_TOOLCHAIN_FILE)
        list(APPEND configure_command  "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
    endif()
    if(CMAKE_MSVC_RUNTIME_LIBRARY)
        list(APPEND configure_command  "-DCMAKE_MSVC_RUNTIME_LIBRARY=${CMAKE_MSVC_RUNTIME_LIBRARY}")
    endif()
    if(CMAKE_OSX_ARCHITECTURES)
        list(APPEND configure_command "-DCMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES}")
    endif()
    if(CMAKE_OSX_DEPLOYMENT_TARGET)
        list(APPEND configure_command "-DCMAKE_OSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET}")
    endif()
    list(APPEND configure_command ${dep_CMAKE_ARGS})
    set(build_commands
        COMMAND ${CMAKE_COMMAND} ${configure_command}
        COMMAND ${CMAKE_COMMAND} --build "${build_dir}" --config "${LOGTEST_THIRD_PARTY_BUILD_TYPE}" --parallel "${CMAKE_BUILD_PARALLEL_LEVEL}"
        COMMAND ${CMAKE_COMMAND} --install "${build_dir}" --config "${LOGTEST_THIRD_PARTY_BUILD_TYPE}" 
        COMMAND ${CMAKE_COMMAND} "-DLOGTEST_DEPS_STAMP_FILE=${cache_stamp}"  "-DLOGTEST_DEPS_STAMP_VALUE=${cache_key}" -P  "${PROJECT_SOURCE_DIR}/cmake/write_dependency_stamp.cmake"
    )
    set(ready_target  "logtest_dep_${dep_NAME}_ready")
    string(REPLACE "-" "_" ready_target "${ready_target}")

    if(cache_complete AND LOGTEST_REUSE_INSTALLED_DEPENDENCIES)
        add_custom_command(
            OUTPUT ${installed_outputs}
            ${build_commands}
            COMMENT "building and installing third_party dependency : ${dep_NAME}"
            VERBATIM
            COMMAND_EXPAND_LISTS
        )
        add_custom_target("${ready_target}" DEPENDS "${installed_outputs}")
        message(STATUS "reuse the third_party ${dep_NAME}")
    else()  
        add_custom_target("${ready_target}"
            ${build_commands}
            COMMENT "rebuild third_party dependency : ${dep_NAME}"
            VERBATIM
            COMMAND_EXPAND_LISTS
        )
        message(STATUS "rebuild the third_party ${dep_NAME}")
    endif()

    if(dep_DEPENDS)
        add_dependencies("${ready_target}" "${dep_DEPENDS}")
    endif()
        
    string(TOUPPER "${dep_NAME}" variable_prefix)
    string(REPLACE  "-" "_"   variable_prefix "${variable_prefix}")
    set("LOGTEST_${variable_prefix}_INSTALL_DIR" "${install_dir}" PARENT_SCOPE)
    set("LOGTEST_${variable_prefix}_CACHE_KEY" "${cache_key}" PARENT_SCOPE)
    set("LOGTEST_${variable_prefix}_CACHE_COMPLETE" "${cache_complete}" PARENT_SCOPE)
    set("LOGTEST_${variable_prefix}_DEPENDENCY_TARGET" "${ready_target}" PARENT_SCOPE)
endfunction()

set(_logtest_static_Library "${CMAKE_STATIC_LIBRARY_PREFIX}@NAME@${CMAKE_STATIC_LIBRARY_SUFFIX}")

set(_logtest_spdlog_source "${LOGTEST_THIRD_PARTY_DIR}/spdlog")
logtest_get_source_revision("${_logtest_spdlog_source}" _logtest_spdlog_revision)
string(REPLACE "@NAME@" "spdlog" _logtest_spdlog_library "${_logtest_static_Library}")
logtest_add_cmake_dependency(
    NAME spdlog
    SOURCE_DIR "${_logtest_spdlog_source}"
    SOURCE_REVISION "${_logtest_spdlog_revision}"
    SENTINELS
        "lib/cmake/spdlog/spdlog-config.cmake"
)

set(_logtest_benchmark_source "${LOGTEST_THIRD_PARTY_DIR}/benchmark")
logtest_get_source_revision("${_logtest_benchmark_source}" _logtest_benchmark_revision)
string(REPLACE "@NAME@" "benchmark" _logtest_benchmark_library "${_logtest_static_Library}")
logtest_add_cmake_dependency(
    NAME benchmark
    SOURCE_DIR "${_logtest_benchmark_source}"
    SOURCE_REVISION "${_logtest_benchmark_revision}"
    CMAKE_ARGS
        "-DBENCHMARK_DOWNLOAD_DEPENDENCIES=on"
    SENTINELS
        "lib/cmake/benchmark/benchmark-config.cmake"
)

if(LOGTEST_SPDLOG_CACHE_COMPLETE)
    find_package(spdlog CONFIG REQUIRED
        PATHS "${LOGTEST_SPDLOG_INSTALL_DIR}"
        NO_DEFAULT_PATH)
else()
    file(MAKE_DIRECTORY "${LOGTEST_SPDLOG_INSTALL_DIR}/include")
    add_library(spdlog STATIC IMPORTED GLOBAL)
    set_target_properties(spdlog PROPERTIES
        IMPORTED_LOCATION "${LOGTEST_SPDLOG_INSTALL_DIR}/lib/${_logtest_spdlog_library}"
        INTERFACE_COMPILE_DEFINITIONS SPDLOG_COMPILED_LIB
        INTERFACE_INCLUDE_DIRECTORIES "${LOGTEST_SPDLOG_INSTALL_DIR}/include"
    )
endif()


if(LOGTEST_BENCHMARK_CACHE_COMPLETE)
    find_package(benchmark CONFIG REQUIRED
        PATHS "${LOGTEST_BENCHMARK_INSTALL_DIR}"
        NO_DEFAULT_PATH)
else()
    file(MAKE_DIRECTORY "${LOGTEST_BENCHMARK_INSTALL_DIR}/include")
    add_library(benchmark STATIC IMPORTED GLOBAL)
    set_target_properties(benchmark PROPERTIES
        IMPORTED_LOCATION "${LOGTEST_BENCHMARK_INSTALL_DIR}/lib/${_logtest_benchmark_library}"
        INTERFACE_COMPILE_DEFINITIONS BENCHMARK_STATIC_DEFINE
        INTERFACE_INCLUDE_DIRECTORIES "${LOGTEST_BENCHMARK_INSTALL_DIR}/include"
    )
    
endif()

add_custom_target(logtest_third_party_dependencies ALL)
add_dependencies(logtest_third_party_dependencies
    "${LOGTEST_BENCHMARK_DEPENDENCY_TARGET}"
    "${LOGTEST_SPDLOG_DEPENDENCY_TARGET}"
)



foreach(_logtest_dependency_install_dir IN ITEMS
    "${LOGTEST_SPDLOG_INSTALL_DIR}"
    "${LOGTEST_BENCHMARK_INSTALL_DIR}"
)
    install(
        DIRECTORY "${_logtest_dependency_install_dir}/"
        DESTINATION "."
        PATTERN ".pans-cache-*" EXCLUDE
    )
endforeach()

