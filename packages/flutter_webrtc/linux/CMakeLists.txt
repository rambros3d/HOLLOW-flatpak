cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "flutter_webrtc")
project(${PROJECT_NAME} LANGUAGES CXX)

if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.24.0")
  cmake_policy(SET CMP0135 NEW)
endif()

get_filename_component(REAL_PACKAGE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." REALPATH)

include("${REAL_PACKAGE_DIR}/third_party/CMakeLists.txt")

set(PLUGIN_NAME "${PROJECT_NAME}_plugin")
set (CMAKE_EXPORT_COMPILE_COMMANDS ON )
set(CMAKE_CXX_STANDARD 17)

add_definitions(-DRTC_DESKTOP_DEVICE)

add_library(${PLUGIN_NAME} SHARED
  "${REAL_PACKAGE_DIR}/common/cpp/src/flutter_data_channel.cc"
  "${REAL_PACKAGE_DIR}/common/cpp/src/flutter_data_packet_cryptor.cc"
  "${REAL_PACKAGE_DIR}/common/cpp/src/flutter_frame_cryptor.cc"
  "${REAL_PACKAGE_DIR}/common/cpp/src/flutter_media_stream.cc"
  "${REAL_PACKAGE_DIR}/common/cpp/src/flutter_utf8_sanitize.cc"
  "${REAL_PACKAGE_DIR}/common/cpp/src/flutter_peerconnection.cc"
  "${REAL_PACKAGE_DIR}/common/cpp/src/flutter_frame_capturer.cc"
  "${REAL_PACKAGE_DIR}/common/cpp/src/flutter_video_renderer.cc"
  "${REAL_PACKAGE_DIR}/common/cpp/src/flutter_screen_capture.cc"
  "${REAL_PACKAGE_DIR}/common/cpp/src/flutter_webrtc.cc"
  "${REAL_PACKAGE_DIR}/common/cpp/src/flutter_webrtc_base.cc"
  "${REAL_PACKAGE_DIR}/common/cpp/src/libwebrtc_missing_symbols.cc"
  "${REAL_PACKAGE_DIR}/common/cpp/src/linux_factory.cc"
  "${REAL_PACKAGE_DIR}/common/cpp/src/flutter_common.cc"
  "flutter_webrtc_plugin.cc"
  "flutter/core_implementations.cc"
  "flutter/standard_codec.cc"
  "flutter/plugin_registrar.cc"
  "task_runner_linux.cc"
)

include_directories(
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/flutter/include"
  "${REAL_PACKAGE_DIR}/common/cpp/include"
  "${REAL_PACKAGE_DIR}/third_party/libwebrtc/include"
  "${REAL_PACKAGE_DIR}/third_party/svpng"
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
# crow-misia/libwebrtc-bin raw WebRTC headers need platform defines
target_compile_definitions(${PLUGIN_NAME} PRIVATE WEBRTC_POSIX WEBRTC_LINUX)
# Suppress nullability warnings in WebRTC headers treated as errors
target_compile_options(${PLUGIN_NAME} PRIVATE -Wno-nullability-completeness)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${REAL_PACKAGE_DIR}/common/cpp/include"
  "${REAL_PACKAGE_DIR}/third_party/libwebrtc/include"
)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)


target_link_libraries(${PLUGIN_NAME} PRIVATE
  "${REAL_PACKAGE_DIR}/third_party/libwebrtc/lib/${FLUTTER_TARGET_PLATFORM}/libwebrtc.a"
)

# Static libwebrtc — shipped from libwebrtc.lib; bundled on Linux
set(flutter_webrtc_bundled_libraries
  ""
  PARENT_SCOPE
)

# Add $ORIGIN to RPATH so that lib/libflutter_webrtc_plugin.so can find lib/libwebrtc.so at runtime
set_property(
    TARGET ${PLUGIN_NAME}
    PROPERTY BUILD_RPATH
    "\$ORIGIN"
)
