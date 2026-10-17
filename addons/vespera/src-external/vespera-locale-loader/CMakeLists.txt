cmake_minimum_required(VERSION 3.16)
project(vespera_locale_loader LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml)

if(NOT DEFINED CMAKE_PREFIX_PATH AND DEFINED ENV{QT_PREFIX})
    set(CMAKE_PREFIX_PATH "$ENV{QT_PREFIX}")
endif()

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)
set(QML_OUTPUT_DIR "${REPO_ROOT}/src/opt/victronenergy/gui/qml/Vespera")
set(TRANSLATION_SOURCE_DIR "${REPO_ROOT}/src-external/gui-v2/Vespera/translations")
set(TRANSLATION_OUTPUT_DIR "${QML_OUTPUT_DIR}/lang")

add_library(vesperalocale SHARED
    src/vesperatranslator.cpp
    src/vesperalocaleplugin.cpp
)

target_include_directories(vesperalocale PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(vesperalocale PRIVATE Qt6::Core Qt6::Gui Qt6::Qml)

set_target_properties(vesperalocale PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${QML_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "${QML_OUTPUT_DIR}"
)

add_custom_command(
    TARGET vesperalocale POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${TRANSLATION_OUTPUT_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${TRANSLATION_SOURCE_DIR}/*.qm
        "${TRANSLATION_OUTPUT_DIR}/"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/qmldir"
        "${QML_OUTPUT_DIR}/qmldir"
)

file(WRITE "${QML_OUTPUT_DIR}/qmldir" "module Vespera\nplugin vesperalocale\nsingleton VesperaDeviceModel 1.0 VesperaDeviceModel.qml\n")
