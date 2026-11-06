cmake_minimum_required(VERSION 3.25)
set(CMAKE_OSX_DEPLOYMENT_TARGET 10.9 CACHE STRING "")
set(CMAKE_OSX_ARCHITECTURES x86_64 CACHE STRING "")
project(ICUUpdater LANGUAGES OBJC)
find_package(MavericksShipyard REQUIRED)
set(MAVERICKS_REQUIRE_APPLECLANG OFF)
include(Mavericks)
include(MavericksSparkle)
if(NOT PKG_VERSION MATCHES "-mavericks\\.[0-9]+$")
  message(FATAL_ERROR "PKG_VERSION must be the pkg's <upstream>-mavericks.N (got '${PKG_VERSION}'); build/build-updater.sh passes it")
endif()
mavericks_add_updater_app(
  PRODUCT icu
  PRODUCT_NAME "ICU for Mavericks"
  ALLOW_GENERIC
  VERSION "${PKG_VERSION}"
  CONFIRM_TITLE "ICU for Mavericks updated"
  CONFIRM_BODY "ICU was updated. Programs that use it get the new version the next time they start.")
