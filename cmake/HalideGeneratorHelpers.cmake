cmake_minimum_required(VERSION 3.14)

define_property(TARGET PROPERTY HL_GEN_TARGET
                BRIEF_DOCS "On a Halide library target, names the generator target used to create it"
                FULL_DOCS "On a Halide library target, names the generator target used to create it")

define_property(TARGET PROPERTY HL_FILTER_NAME
                BRIEF_DOCS "On a Halide library target, names the filter this library corresponds to"
                FULL_DOCS "On a Halide library target, names the filter this library corresponds to")

define_property(TARGET PROPERTY HL_LIBNAME
                BRIEF_DOCS "On a Halide library target, names the function it provides"
                FULL_DOCS "On a Halide library target, names the function it provides")

define_property(TARGET PROPERTY HL_RUNTIME
                BRIEF_DOCS "On a Halide library target, names the runtime target it depends on"
                FULL_DOCS "On a Halide library target, names the runtime target it depends on")

define_property(TARGET PROPERTY HL_PARAMS
                BRIEF_DOCS "On a Halide library target, lists the parameters used to configure the filter"
                FULL_DOCS "On a Halide library target, lists the parameters used to configure the filter")

define_property(TARGET PROPERTY HL_TARGET
                BRIEF_DOCS "On a Halide library target, lists the runtime targets supported by the filter"
                FULL_DOCS "On a Halide library target, lists the runtime targets supported by the filter")

function(add_halide_library TARGET)
    set(options GRADIENT_DESCENT)
    set(oneValueArgs FROM GENERATOR FUNCTION_NAME USE_RUNTIME)
    set(multiValueArgs PARAMS EXTRA_OUTPUTS TARGETS FEATURES)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (ARG_GRADIENT_DESCENT)
        set(GRADIENT_DESCENT 1)
    else ()
        set(GRADIENT_DESCENT 0)
    endif ()

    if (NOT ARG_FROM)
        message(FATAL_ERROR "Missing FROM argument specifying a Halide generator target")
    endif ()

    if (NOT ARG_GENERATOR)
        set(ARG_GENERATOR "${TARGET}")
    endif ()

    if (NOT ARG_FUNCTION_NAME)
        set(ARG_FUNCTION_NAME "${ARG_GENERATOR}")
    endif ()

    if (NOT ARG_TARGETS)
        set(ARG_TARGETS host)
    endif ()

    set(TARGETS)
    foreach (T IN LISTS ARG_TARGETS)
        if (NOT T)
            set(T host)
        endif ()
        foreach (F IN LISTS ARG_FEATURES)
            set(T "${T}-${F}")
        endforeach ()
        list(APPEND TARGETS "${T}-no_runtime")
    endforeach ()
    string(REPLACE ";" "," TARGETS "${TARGETS}")

    if (NOT ARG_USE_RUNTIME)
        add_library("${TARGET}.runtime" STATIC IMPORTED)
        target_link_libraries("${TARGET}.runtime" INTERFACE ${CMAKE_DL_LIBS})
        add_custom_command(OUTPUT "${TARGET}.runtime.a"
                           COMMAND "${ARG_FROM}" -r "${TARGET}.runtime" -o . target=${TARGETS})
        add_custom_target("${TARGET}.runtime.update"
                          DEPENDS "${TARGET}.runtime.a")
        set_target_properties("${TARGET}.runtime" PROPERTIES IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}.runtime.a")
        add_dependencies("${TARGET}.runtime" "${TARGET}.runtime.update")
        set(ARG_USE_RUNTIME "${TARGET}.runtime")
    endif ()

    # TODO: handle extra outputs

    ##
    # Main library target for filter.
    ##

    add_library("${TARGET}" STATIC IMPORTED)

    set_target_properties("${TARGET}" PROPERTIES
                          HL_GEN_TARGET "${ARG_FROM}"
                          HL_FILTER_NAME "${ARG_GENERATOR}"
                          HL_LIBNAME "${ARG_FUNCTION_NAME}"
                          HL_PARAMS "${ARG_PARAMS}"
                          HL_TARGET "${TARGETS}")

    add_custom_command(OUTPUT
                       "${TARGET}.a"
                       "${TARGET}.h"
                       "${TARGET}.registration.cpp"
                       COMMAND "${ARG_FROM}" -n "${TARGET}" -d "${GRADIENT_DESCENT}" -g "${ARG_GENERATOR}" -f "${ARG_FUNCTION_NAME}" -o . target=${TARGETS} ${ARG_PARAMS}
                       DEPENDS "${ARG_FROM}")

    add_custom_target("${TARGET}.update"
                      DEPENDS
                      "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}.a"
                      "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}.h"
                      "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}.registration.cpp")

    set_target_properties("${TARGET}" PROPERTIES IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}.a")
    add_dependencies("${TARGET}" "${TARGET}.update")

    target_include_directories("${TARGET}" INTERFACE "${CMAKE_CURRENT_BINARY_DIR}")
    target_link_libraries("${TARGET}" INTERFACE "${ARG_USE_RUNTIME}")
endfunction()