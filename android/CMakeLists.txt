project(NitroAliPush)
cmake_minimum_required(VERSION 3.9.0)

set (PACKAGE_NAME NitroAliPush)
set (CMAKE_VERBOSE_MAKEFILE ON)
set (CMAKE_CXX_STANDARD 20)

# 定义 C++ 库（具体的源文件由 Nitro 代码生成器自动加入）。
add_library(${PACKAGE_NAME} SHARED)

set(NITRO_SANITIZER "" CACHE STRING "Native sanitizer")
if(NITRO_SANITIZER STREQUAL "address")
  target_compile_options(${PACKAGE_NAME} PUBLIC -fsanitize=address -fno-omit-frame-pointer)
  set_target_properties(${PACKAGE_NAME} PROPERTIES LINK_FLAGS "-fsanitize=address")
elseif(NOT NITRO_SANITIZER STREQUAL "")
  message(FATAL_ERROR "Unsupported NITRO_SANITIZER: ${NITRO_SANITIZER}")
endif()

# 引入 Nitro 生成的自动链接脚本与所有生成的 C++ 源文件。
include(${CMAKE_SOURCE_DIR}/../nitrogen/generated/android/NitroAliPush+autolinking.cmake)

# 本地头文件包含目录。
include_directories("src/main/cpp")

# 日志库与 Android 核心库。
find_library(LOG_LIB log)
target_link_libraries(
  ${PACKAGE_NAME}
  ${LOG_LIB}
  android # <-- Android core
)
