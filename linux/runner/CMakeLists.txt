cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Crea l’eseguibile
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  # Chiama fl_register_plugins
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Aggiunge le opzioni standard (C++14, -Wall, etc.)
apply_standard_settings(${BINARY_NAME})

# Application ID (se usi la define)
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Linka contro la libreria “flutter” (definita in linux/flutter/ephemeral)
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
# Linka GTK (pkg-config)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

# Se serve, includi directory aggiuntive
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
