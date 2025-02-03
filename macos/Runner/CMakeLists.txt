# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(thesis_project LANGUAGES CXX)

set(BINARY_NAME "thesis_project")

# Configurazione per Homebrew e librerie di sistema
include_directories(/usr/local/include)
link_directories(/usr/local/lib)
list(APPEND CMAKE_PREFIX_PATH /usr/local/opt/portaudio)
list(APPEND CMAKE_PREFIX_PATH /usr/local/opt/libsndfile)

# Configurazione FetchContent per le dipendenze
include(FetchContent)

# Configurazione per scaricare e compilare PortAudio
FetchContent_Declare(
    portaudio
    GIT_REPOSITORY https://github.com/PortAudio/portaudio.git
    GIT_TAG v19.7.0
)
FetchContent_MakeAvailable(portaudio)

# Configurazione per scaricare e compilare libsndfile
FetchContent_Declare(
    libsndfile
    GIT_REPOSITORY https://github.com/libsndfile/libsndfile.git
    GIT_TAG 1.2.0
)
FetchContent_MakeAvailable(libsndfile)

# Configurazione del tipo di build
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE
    STRING "Flutter build mode" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Profile" "Release")
endif()

# Impostazioni di compilazione standard
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE -Wall -Werror)
  target_compile_options(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O3>")
  target_compile_definitions(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:NDEBUG>")

  # Definizioni per il supporto audio
  target_compile_definitions(${TARGET} PRIVATE
    "HAVE_PORTAUDIO"
    "HAVE_SNDFILE"
  )
endfunction()

# Application build
add_executable(${BINARY_NAME} MACOSX_BUNDLE
  "main.mm"
  "AppDelegate.mm"
  "MainFlutterWindow.mm"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Applica le impostazioni standard
apply_standard_settings(${BINARY_NAME})

# Directory per i file di intestazione
target_include_directories(${BINARY_NAME} PRIVATE
  "${CMAKE_SOURCE_DIR}"
  "${portaudio_SOURCE_DIR}/include"
  "${libsndfile_SOURCE_DIR}/include"
  "${CMAKE_CURRENT_SOURCE_DIR}"
)

# Link delle librerie
target_link_libraries(${BINARY_NAME} PRIVATE
  flutter
  portaudio_static
  sndfile
  "-framework CoreAudio"
  "-framework AudioToolbox"
  "-framework AudioUnit"
  "-framework CoreServices"
  "-framework Carbon"
)

# Configurazione runtime
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E make_directory
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/Contents/Frameworks"

  # Copia librerie compilate
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    $<TARGET_FILE:portaudio>
    $<TARGET_FILE:sndfile>
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/Contents/Frameworks"
)

# Add dependencies
add_dependencies(${BINARY_NAME}
  flutter_assemble
  portaudio
  sndfile
)

# Bundle configuration
set_target_properties(${BINARY_NAME} PROPERTIES
  MACOSX_BUNDLE_GUI_IDENTIFIER "unito.lorenzodm.thesis_project"
  MACOSX_BUNDLE_BUNDLE_VERSION "${VERSION}"
  MACOSX_BUNDLE_SHORT_VERSION_STRING "${VERSION}"
  MACOSX_BUNDLE_COPYRIGHT "© 2025 Lorenzo Di Midolo"
  MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist
)