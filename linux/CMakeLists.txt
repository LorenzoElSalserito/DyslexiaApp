# Configurazione a livello di progetto
cmake_minimum_required(VERSION 3.10)
project(runner LANGUAGES CXX)

# Nome dell'eseguibile e identificativo dell'applicazione
set(BINARY_NAME "thesis_project")
set(APPLICATION_ID "unito.lorenzodm.thesis_project")

# Definizione delle dipendenze necessarie
set(REQUIRED_PACKAGES
    "gtk+-3.0"             # GTK3 UI toolkit
    "libpulse"             # PulseAudio
    "libpulse-mainloop-glib" # PulseAudio main loop
    "portaudio-2.0"        # PortAudio
    "alsa"                 # ALSA
)

# Le dipendenze opzionali vengono verificate ma non bloccano la build
set(OPTIONAL_PACKAGES
    "libpipewire-0.3"      # PipeWire
    "sndfile"              # Audio file support
)

# Funzione per la verifica delle dipendenze
function(check_dependencies)
    message(STATUS "Verifica delle dipendenze...")
    find_package(PkgConfig REQUIRED)

    set(MISSING_REQUIRED "")
    set(MISSING_OPTIONAL "")

    foreach(PACKAGE ${REQUIRED_PACKAGES})
        pkg_check_modules(PC_${PACKAGE} QUIET ${PACKAGE})
        if(NOT PC_${PACKAGE}_FOUND)
            list(APPEND MISSING_REQUIRED ${PACKAGE})
        endif()
    endforeach()

    foreach(PACKAGE ${OPTIONAL_PACKAGES})
        pkg_check_modules(PC_${PACKAGE} QUIET ${PACKAGE})
        if(NOT PC_${PACKAGE}_FOUND)
            list(APPEND MISSING_OPTIONAL ${PACKAGE})
        endif()
    endforeach()

    if(MISSING_REQUIRED)
        message("\nMancano le seguenti dipendenze richieste:")
        foreach(PKG ${MISSING_REQUIRED})
            message("  - ${PKG}")
        endforeach()

        message("\nPer installare tutte le dipendenze necessarie su Linux, esegui:")
        message("sudo apt-get update")
        message("sudo apt-get install --reinstall \\")
        message("    libgtk-3-dev \\")
        message("    libpulse-dev \\")
        message("    libpulse-mainloop-glib0 \\")
        message("    portaudio19-dev \\")
        message("    libasound2-dev \\")
        message("    libvosk-dev")
        message(FATAL_ERROR "Dipendenze richieste mancanti. Installa i pacchetti necessari e riprova.")
    endif()
endfunction()

# Configurazioni di base
cmake_policy(SET CMP0063 NEW)
set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Configurazione tipo di build
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Profile" "Release")
endif()

# Verifica le dipendenze
find_package(PkgConfig REQUIRED)
check_dependencies()

# Verifica la versione di GTK3 separatamente
pkg_check_modules(GTK3 REQUIRED IMPORTED_TARGET "gtk+-3.0")
if(GTK3_VERSION VERSION_LESS 3.20)
    message(FATAL_ERROR "GTK3 version must be at least 3.20 (found ${GTK3_VERSION})")
endif()

# Configurazione delle altre librerie richieste
pkg_check_modules(PULSE REQUIRED IMPORTED_TARGET libpulse)
pkg_check_modules(PULSE_GLIB REQUIRED IMPORTED_TARGET libpulse-mainloop-glib)
pkg_check_modules(PORTAUDIO REQUIRED IMPORTED_TARGET portaudio-2.0)
pkg_check_modules(ALSA REQUIRED IMPORTED_TARGET alsa)

# Crea un alias per la compatibilità con vosk_flutter
add_library(PkgConfig::GTK ALIAS PkgConfig::GTK3)

# Impostazioni di compilazione standard
function(APPLY_STANDARD_SETTINGS TARGET)
    target_compile_features(${TARGET} PUBLIC cxx_std_17)
    target_compile_options(${TARGET} PRIVATE -Wall -Werror)
    target_compile_options(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O3>")
    target_compile_definitions(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:NDEBUG>")

    target_compile_definitions(${TARGET} PRIVATE
        "HAVE_PULSE"
        "HAVE_ALSA"
        "PERMISSION_HANDLER_LINUX"
        "APPLICATION_ID=\"${APPLICATION_ID}\""
    )
endfunction()

# Flutter library e build rules
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Target dell'applicazione
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "vosk_flutter_plugin.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Applica le impostazioni standard
apply_standard_settings(${BINARY_NAME})

# Link delle librerie
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE
    PkgConfig::GTK3
    PkgConfig::PULSE
    PkgConfig::PULSE_GLIB
    PkgConfig::PORTAUDIO
    PkgConfig::ALSA
)

# Dipendenze Flutter
add_dependencies(${BINARY_NAME} flutter_assemble)

# Plugin build rules
include(flutter/generated_plugins.cmake)

# === Installazione ===
set(BUILD_BUNDLE_DIR "${PROJECT_BINARY_DIR}/bundle")
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

# Directory di installazione
set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")

# Installazione dei componenti
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
    COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
    COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
    install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
        DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
        COMPONENT Runtime)
endif()

# Asset e librerie
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/linux/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)

set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
    file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
" COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
    DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

if(NOT CMAKE_BUILD_TYPE MATCHES "Debug")
    install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
        COMPONENT Runtime)
endif()