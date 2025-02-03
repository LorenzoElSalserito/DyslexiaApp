cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Configurazione per il download automatico delle dipendenze
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

# Target dell'applicazione
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Applicazione delle impostazioni standard
apply_standard_settings(${BINARY_NAME})

# Definizioni per la versione di build
target_compile_definitions(${BINARY_NAME} PRIVATE
  "FLUTTER_VERSION=\"${FLUTTER_VERSION}\""
  "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}"
  "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}"
  "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}"
  "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}"
)

# Disabilitazione macro Windows che collidono con la libreria standard C++
target_compile_definitions(${BINARY_NAME} PRIVATE
  "NOMINMAX"
  "WIN32_LEAN_AND_MEAN"
  "PA_USE_WASAPI=1"
  "PA_USE_WDMKS=1"
  "PA_ENABLE_DEBUG_OUTPUT"
)

# Directory per i file di intestazione
target_include_directories(${BINARY_NAME} PRIVATE
  "${CMAKE_SOURCE_DIR}"
  "${portaudio_SOURCE_DIR}/include"
  "${libsndfile_SOURCE_DIR}/include"
)

# Librerie di dipendenza
target_link_libraries(${BINARY_NAME} PRIVATE
  flutter
  flutter_wrapper_app
  portaudio_static
  sndfile
  "dwmapi.lib"
  "winmm.lib"     # Windows Multimedia
  "ole32.lib"     # COM support
  "uuid.lib"      # GUID support
  "setupapi.lib"  # Device setup
  "ksuser.lib"    # Kernel Streaming
)

# Configurazioni per il runtime
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  # Copia le DLL necessarie nella directory di output
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    $<TARGET_FILE:portaudio>
    $<TARGET_FILE:sndfile>
    $<TARGET_FILE_DIR:${BINARY_NAME}>
)

# Configurazione delle dipendenze Flutter
add_dependencies(${BINARY_NAME}
  flutter_assemble
  portaudio
  sndfile
)

# Configurazione delle proprietà del target
set_target_properties(${BINARY_NAME} PROPERTIES
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED ON
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

# Impostazioni di ottimizzazione per il rilascio
if(CMAKE_BUILD_TYPE MATCHES "Release")
  target_compile_options(${BINARY_NAME} PRIVATE
    /O2     # Massima ottimizzazione
    /Oi     # Genera funzioni intrinseche
    /GL     # Ottimizzazione per intero programma
  )
  target_link_options(${BINARY_NAME} PRIVATE
    /LTCG   # Link-time code generation
  )
endif()

# Configurazione debug
if(CMAKE_BUILD_TYPE MATCHES "Debug")
  target_compile_definitions(${BINARY_NAME} PRIVATE
    "_DEBUG"
    "PA_ENABLE_DEBUG_OUTPUT"
  )
endif()