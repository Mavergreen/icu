cmake_minimum_required(VERSION 3.25)

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/UPSTREAM_VERSION" ICU_UPSTREAM LIMIT_COUNT 1)
set(ICU_VERSION "${ICU_UPSTREAM}")
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION")
  file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" ICU_VERSION LIMIT_COUNT 1)
endif()

project(ICUForMavericks LANGUAGES C)

find_package(MavericksShipyard REQUIRED)
include(Mavericks)
include(MavericksMode)
mavericks_build_mode(MAVERICKS_MODE)
mavericks_require_expected_mode("${MAVERICKS_MODE}")
message(STATUS "ICU for Mavericks ${ICU_VERSION}: build mode ${MAVERICKS_MODE}")

option(ICU_BUILD_UPDATER "Build the Sparkle updater (needs icu in the installed shipyard's product registry)" OFF)

if(ICU_BUILD_UPDATER)
  include(MavericksSparkle)
  mavericks_add_updater_app(
    PRODUCT icu
    PRODUCT_NAME "ICU for Mavericks"
    ALLOW_GENERIC
    VERSION "${ICU_VERSION}"
    CONFIRM_TITLE "ICU for Mavericks updated"
    CONFIRM_BODY "ICU was updated. Programs that use it get the new version the next time they start.")
endif()
