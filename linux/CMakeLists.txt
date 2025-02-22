cmake_minimum_required(VERSION 3.10)

# Mostra i comandi di build e linker a schermo
set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -v")

# Nome del progetto e linguaggi
project(runner LANGUAGES CXX)

# Se la variabile di installazione non è inizializzata, la impostiamo nel bundle
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/bundle" CACHE PATH "..." FORCE)
endif()

# Nome dell'eseguibile (Flutter di solito usa "runner" o simili)
set(BINARY_NAME "thesis_project")
set(APPLICATION_ID "unito.lorenzodm.thesis_project")

#include <record_linux/record_linux_plugin.h>


# Impostazioni predefinite di RPATH
set(CMAKE_SKIP_BUILD_RPATH FALSE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)
set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

# Se non è specificato, compila in Debug
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Flutter build mode" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Profile" "Release")
endif()

# --- GESTIONE DIPENDENZE ---
find_package(PkgConfig REQUIRED)

# Adatta i pacchetti richiesti alle tue necessità
set(REQUIRED_PACKAGES
  "gtk+-3.0"
  "libpulse"
  "libpulse-mainloop-glib"
  "portaudio-2.0"
  "alsa"
)

function(check_dependencies)
  message(STATUS "Verifica delle dipendenze di sistema...")
  set(MISSING_REQUIRED "")
  foreach(PACKAGE ${REQUIRED_PACKAGES})
    pkg_check_modules(PC_${PACKAGE} QUIET ${PACKAGE})
    if(NOT PC_${PACKAGE}_FOUND)
      list(APPEND MISSING_REQUIRED ${PACKAGE})
    endif()
  endforeach()
  if(MISSING_REQUIRED)
    message("\nMancano le seguenti dipendenze richieste:")
    foreach(PKG ${MISSING_REQUIRED})
      message("  - ${PKG}")
    endforeach()
    message("\nPer installare tutte le dipendenze necessarie su Linux, esegui ad esempio:")
    message("  sudo apt-get update")
    message("  sudo apt-get install --reinstall \\")
    message("       libgtk-3-dev libpulse-dev libpulse-mainloop-glib0 portaudio19-dev libasound2-dev")
    message(FATAL_ERROR "Dipendenze richieste mancanti. Installa i pacchetti necessari e riprova.")
  endif()
endfunction()

check_dependencies()

# Importa i package trovati
pkg_check_modules(GTK3 REQUIRED IMPORTED_TARGET gtk+-3.0)
pkg_check_modules(PULSE REQUIRED IMPORTED_TARGET libpulse)
pkg_check_modules(PULSE_GLIB REQUIRED IMPORTED_TARGET libpulse-mainloop-glib)
pkg_check_modules(PORTAUDIO REQUIRED IMPORTED_TARGET portaudio-2.0)
pkg_check_modules(ALSA REQUIRED IMPORTED_TARGET alsa)
add_library(PkgConfig::GTK ALIAS PkgConfig::GTK3)

cmake_policy(SET CMP0063 NEW)

# --- LOGICA PER VOSK (Download / Estrazione / Verifica) ---
# Adatta i link e i percorsi secondo le tue esigenze
set(VOSK_MODEL_NAME "vosk-model-small-it-0.22")
set(VOSK_DIR "${CMAKE_BINARY_DIR}/vosk_model")
set(VOSK_BUNDLE_DIR "${CMAKE_INSTALL_PREFIX}/lib/vosk")
set(VOSK_LIB_DIR "${CMAKE_BINARY_DIR}/vosk-lib")
set(VOSK_LIB_URL "https://github.com/alphacep/vosk-api/releases/download/v0.3.45/vosk-linux-x86_64-0.3.45.zip")
set(VOSK_MODEL_URL "https://alphacephei.com/vosk/models/${VOSK_MODEL_NAME}.zip")
set(VOSK_ZIP_FILE "${CMAKE_BINARY_DIR}/${VOSK_MODEL_NAME}.zip")
set(VOSK_LIB_ZIP "${CMAKE_BINARY_DIR}/vosk-lib.zip")

# Scarica ed estrai la libreria VOSK se non presente
if(NOT EXISTS ${VOSK_LIB_ZIP})
  message(STATUS "Scaricando la libreria VOSK da ${VOSK_LIB_URL}")
  file(DOWNLOAD
    ${VOSK_LIB_URL}
    ${VOSK_LIB_ZIP}
    SHOW_PROGRESS
    STATUS DOWNLOAD_STATUS
    TLS_VERIFY ON
  )
  list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
  list(GET DOWNLOAD_STATUS 1 ERROR_MESSAGE)
  if(NOT STATUS_CODE EQUAL 0)
    file(REMOVE ${VOSK_LIB_ZIP})
    message(FATAL_ERROR "Errore nel download della libreria VOSK: ${ERROR_MESSAGE}")
  endif()
endif()

if(NOT EXISTS ${VOSK_LIB_DIR})
  message(STATUS "Estrazione della libreria VOSK...")
  file(MAKE_DIRECTORY ${VOSK_LIB_DIR})
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E tar xf ${VOSK_LIB_ZIP}
    WORKING_DIRECTORY ${VOSK_LIB_DIR}
    RESULT_VARIABLE EXTRACT_RESULT
    ERROR_VARIABLE EXTRACT_ERROR
  )
  if(NOT EXTRACT_RESULT EQUAL 0)
    message(FATAL_ERROR "Errore nell'estrazione di VOSK: ${EXTRACT_ERROR}")
  endif()
  set(REQUIRED_FILES "${VOSK_LIB_DIR}/vosk-linux-x86_64-0.3.45/libvosk.so")
  foreach(FILE ${REQUIRED_FILES})
    if(NOT EXISTS ${FILE})
      message(FATAL_ERROR "File di libreria VOSK mancante: ${FILE}")
    endif()
  endforeach()
endif()

# Scarica/estrai il modello VOSK
if(NOT EXISTS "${VOSK_DIR}/${VOSK_MODEL_NAME}")
  if(NOT EXISTS ${VOSK_ZIP_FILE})
    message(STATUS "Scaricando il modello VOSK da ${VOSK_MODEL_URL}")
    file(DOWNLOAD
      ${VOSK_MODEL_URL}
      ${VOSK_ZIP_FILE}
      SHOW_PROGRESS
      STATUS DOWNLOAD_STATUS
    )
    list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
    if(NOT STATUS_CODE EQUAL 0)
      file(REMOVE ${VOSK_ZIP_FILE})
      message(FATAL_ERROR "Errore nel download del modello VOSK")
    endif()
  endif()
  message(STATUS "Estrazione del modello VOSK...")
  file(MAKE_DIRECTORY ${VOSK_DIR})
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E tar xf ${VOSK_ZIP_FILE}
    WORKING_DIRECTORY ${VOSK_DIR}
    RESULT_VARIABLE EXTRACT_RESULT
  )
  if(NOT EXTRACT_RESULT EQUAL 0)
    message(FATAL_ERROR "Errore nell'estrazione del modello VOSK")
  endif()
endif()

# Verifica file critici del modello
set(REQUIRED_MODEL_FILES
  "${VOSK_DIR}/${VOSK_MODEL_NAME}/am/final.mdl"
  "${VOSK_DIR}/${VOSK_MODEL_NAME}/conf/mfcc.conf"
  "${VOSK_DIR}/${VOSK_MODEL_NAME}/graph/HCLr.fst"
)
foreach(FILE ${REQUIRED_MODEL_FILES})
  if(NOT EXISTS ${FILE})
    message(FATAL_ERROR "File del modello VOSK mancante: ${FILE}")
  endif()
endforeach()

# --- FUNZIONE PER IMPOSTAZIONI STANDARD ---
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE -Wall -Werror)
  target_compile_options(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O3>")
  target_compile_definitions(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:NDEBUG>")
  target_compile_definitions(${TARGET} PRIVATE
    "HAVE_PULSE"
    "HAVE_ALSA"
    "HAVE_VOSK"
    "VOSK_MODEL_PATH=\"${VOSK_BUNDLE_DIR}\""
    "VOSK_LIB_PATH=\"${CMAKE_INSTALL_PREFIX}/lib\""
    "PERMISSION_HANDLER_LINUX"
    "APPLICATION_ID=\"${APPLICATION_ID}\""
  )
endfunction()

# --- INCLUDI FLUTTER ---
# (Questa cartella di solito contiene un file CMakeLists e generated_plugins.cmake)
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

#
# 1) Creiamo il target dell’applicazione
# 2) Applichiamo le impostazioni standard
# 3) Linkiamo le librerie (incluso VOSK)
# 4) Infine, includiamo i plugin generati con generated_plugins.cmake
#

add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "vosk_flutter_plugin.cc"
  # File generato da Flutter che chiama fl_register_plugins
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

APPLY_STANDARD_SETTINGS(${BINARY_NAME})

# Link a Flutter, VOSK, GTK, etc.
target_link_libraries(${BINARY_NAME} PRIVATE
  # Flutter
  flutter
  # Libreria di VOSK
  ${VOSK_LIB_DIR}/vosk-linux-x86_64-0.3.45/libvosk.so
  # Librerie di sistema
  PkgConfig::GTK3
  PkgConfig::PULSE
  PkgConfig::PULSE_GLIB
  PkgConfig::PORTAUDIO
  PkgConfig::ALSA
  pthread
  dl
)

# Includi le directory di intestazione
target_include_directories(${BINARY_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/include/vosk_flutter"
  "${CMAKE_CURRENT_SOURCE_DIR}/include/flutter_linux"
  "${VOSK_DIR}"
  "${VOSK_LIB_DIR}/vosk-linux-x86_64-0.3.45/"
  "${CMAKE_CURRENT_SOURCE_DIR}/flutter/ephemeral/.plugin_symlinks/record_linux/linux/include"
)

# 1) Includi la cartella di Flutter (così si costruisce la libreria Flutter)
add_subdirectory(${FLUTTER_MANAGED_DIR} "${CMAKE_BINARY_DIR}/flutter_build")

# 2) Includi i plugin generati (questo esegue add_subdirectory per ogni plugin)
include("${FLUTTER_MANAGED_DIR}/generated_plugins.cmake")

#
# Se 'generated_plugins.cmake' crea subdirectory per 'record_linux',
# NON aggiungere manualmente "add_subdirectory" per record_linux,
# altrimenti genererai duplicati.
#

# --- Installazione (bundle) ---
set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)
install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)

# Copia la libreria di VOSK
install(DIRECTORY "${VOSK_DIR}/${VOSK_MODEL_NAME}/" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}/vosk" COMPONENT Runtime)
install(FILES "${VOSK_LIB_DIR}/vosk-linux-x86_64-0.3.45/libvosk.so" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
endif()

# Gestione eventuali asset nativi
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/linux/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)

# Gestione degli asset Flutter
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")" COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# AOT (per release)
if(NOT CMAKE_BUILD_TYPE MATCHES "Debug")
  install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
endif()

# RPATH
set_target_properties(${BINARY_NAME} PROPERTIES
  BUILD_WITH_INSTALL_RPATH TRUE
  INSTALL_RPATH "$ORIGIN/lib"
)

# Target custom per l'esecuzione (facoltativo)
set(DART_DEFINE_VALUE "VOSK_LIB_PATH=${INSTALL_BUNDLE_LIB_DIR}")
add_custom_target(run_flutter
  COMMAND flutter run --dart-define=${DART_DEFINE_VALUE}
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  COMMENT "Esecuzione dell'app Flutter con dart-define per VOSK_LIB_PATH"
)
