#打开 qt 编译工具
SET(CMAKE_AUTOUIC ON)
SET(CMAKE_AUTOMOC ON)
SET(CMAKE_AUTORCC ON)
SET(CMAKE_INCLUDE_CURRENT_DIR ON)
SET(CMAKE_VERBOSE_MAKEFILE ON)

#需要的QT组件  
SET(QT_COMPONENTS Core Gui Widgets Network Xml Multimedia)
find_package(Qt5 COMPONENTS ${QT_COMPONENTS} REQUIRED)
message("Qt5_VERSION:${Qt5_VERSION}")
if(Qt5_VERSION VERSION_LESS "5.0.0")
    message(FATAL_ERROR "Current qt version:${Qt5_VERSION}, Qt must greater then 5.0.0")
endif()
FOREACH(_COMPONENT ${QT_COMPONENTS})
    SET(QT_LIBRARIES ${QT_LIBRARIES} ${Qt5${_COMPONENT}_LIBRARIES})
ENDFOREACH()
FIND_PACKAGE(Qt5 COMPONENTS WebKitWidgets)
IF(Qt5WebKitWidgets_FOUND)
    ADD_DEFINITIONS(-DRABBITIM_WEBKIT)
    SET(QT_LIBRARIES ${QT_LIBRARIES} ${Qt5WebKitWidgets_LIBRARIES})
ENDIF(Qt5WebKitWidgets_FOUND)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "" FORCE)
endif()

include(CheckCXXCompilerFlag)
include(CheckIncludeFiles)
include(CheckLibraryExists)
include(cmake/RabbitImUtils.cmake)

if(CMAKE_SIZEOF_VOID_P MATCHES 8)
  message(STATUS "64-bit build")
  SET(RABBITIM_ARCHITECTURE "x64")
else()
  message(STATUS "32-bit build")
  SET(RABBITIM_ARCHITECTURE "x86")
endif()

# Exit for blacklisted compilers (those that don't support C++11 very well)
#  MSVC++ 8.0  _MSC_VER == 1400 (Visual Studio 2005)
#  Clang 3.0
SET(BAD_CXX_MESSAGE "")
IF(MSVC)
    IF(MSVC_VERSION LESS 1500)
      SET(BAD_CXX_MESSAGE "MSVC 2008 or higher")
    ENDIF()
ENDIF()
IF("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    IF(${CMAKE_CXX_COMPILER_VERSION} VERSION_LESS 3.1.0)
      SET(BAD_CXX_MESSAGE "Clang v3.1.0 or higher")
    ENDIF()
ENDIF()
IF(BAD_CXX_MESSAGE)
    MESSAGE(FATAL_ERROR "\nSorry, ${BAD_CXX_MESSAGE} is required to build this software. Please retry using a modern compiler that supports C++11 lambdas.")
ENDIF()
IF(NOT MSVC)
    SET(CMAKE_CXX_FLAGS "-std=c++0x") #启用C++11
ENDIF(NOT MSVC)

#
# Compiler & linker settings
#
if(CMAKE_COMPILER_IS_GNUCXX OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
  check_cxx_compiler_flag(-Wunused-but-set-variable HAVE_GXX_UNUSED_BUT_SET)
  check_cxx_compiler_flag(-Wlogical-op HAVE_GXX_LOGICAL_OP)
  check_cxx_compiler_flag(-Wsizeof-pointer-memaccess HAVE_GXX_POINTER_MEMACCESS)
  check_cxx_compiler_flag(-Wreorder HAVE_GXX_REORDER)
  check_cxx_compiler_flag(-Wformat-security HAVE_GXX_FORMAT_SECURITY)
  check_cxx_compiler_flag(-std=c++0x HAVE_GXX_CXX11)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-deprecated -Wextra -Woverloaded-virtual -Winit-self -Wmissing-include-dirs -Wunused -Wno-div-by-zero -Wundef -Wpointer-arith -Wmissing-noreturn -Werror=return-type")
  if(APPLE)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++") # required in C++11 mode
  endif()
  if(HAVE_GXX_CXX11)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++0x")
  endif()
  if(HAVE_GXX_UNUSED_BUT_SET)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wunused-but-set-variable")
  endif()
  if(HAVE_GXX_LOGICAL_OP)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wlogical-op")
  endif()
  if(HAVE_GXX_POINTER_MEMACCESS)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wsizeof-pointer-memaccess")
  endif()
  if(HAVE_GXX_REORDER)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wreorder")
  endif()
  if(HAVE_GXX_FORMAT_SECURITY)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wformat -Wformat-security")
  endif()
  if(MINGW)
    # mingw will error out on the crazy casts in probe.cpp without this
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fpermissive")
  else()
    # visibility attributes not supported on mingw, don't use -fvisibility option
    # see: http://stackoverflow.com/questions/7994415/mingw-fvisibility-hidden-does-not-seem-to-work
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fvisibility=hidden")
  endif()
endif()

if(WIN32)
  add_definitions(-DUNICODE -D_UNICODE)
endif()

# linker flags
if(CMAKE_SYSTEM_NAME MATCHES Linux OR CMAKE_SYSTEM_NAME STREQUAL GNU)
  if(CMAKE_COMPILER_IS_GNUCXX OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    set(CMAKE_SHARED_LINKER_FLAGS "-Wl,--fatal-warnings -Wl,--no-undefined -lc ${CMAKE_SHARED_LINKER_FLAGS}")
    set(CMAKE_MODULE_LINKER_FLAGS "-Wl,--fatal-warnings -Wl,--no-undefined -lc ${CMAKE_MODULE_LINKER_FLAGS}")
  endif()
endif()

# Add definitions for static/style library 
option(BUILD_SHARED_LIBS "Build shared library" ON)
MESSAGE("Build shared library: ${BUILD_SHARED_LIBS}")
IF(BUILD_SHARED_LIBS)
    ADD_DEFINITIONS(-DQT_SHARED)
ELSE(BUILD_SHARED_LIBS)
    ADD_DEFINITIONS(-DQT_STATIC -DRABBITIM_STATIC)
    set(CMAKE_LD_FLAGS "${CMAKE_LD_FLAGS} -static") 
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static")   
ENDIF(BUILD_SHARED_LIBS)

IF(CMAKE_BUILD_TYPE MATCHES Debug)
    ADD_DEFINITIONS(-DDEBUG) # -DDEBUG_VIDEO_TIME )
    SET(RABBIT_CONFIG Debug)
else()
    SET(RABBIT_CONFIG Release)
ENDIF()

IF(MSVC)
    SET(RABBITIM_SYSTEM windows)
    SET(TOOLCHAIN_NAME windows_msvc)
    SET(RABBIT_TOOLCHAIN_VERSION $ENV{RABBIT_TOOLCHAIN_VERSION})
    if(NOT RABBIT_TOOLCHAIN_VERSION)
        SET(VisualStudioVersion $ENV{VisualStudioVersion})
        #mark_as_advanced(VisualStudioVersion)
        if(VisualStudioVersion VERSION_EQUAL 12.0)
            SET(RABBIT_TOOLCHAIN_VERSION 12)
        elseif(VisualStudioVersion VERSION_EQUAL 14.0)
            SET(RABBIT_TOOLCHAIN_VERSION 14)
        elseif(VisualStudioVersion VERSION_EQUAL 15.0)
            SET(RABBIT_TOOLCHAIN_VERSION 15)
        else()
            message(FATAL_ERROR "Don't support msvc version: ${VisualStudioVersion}; please use msvc 2013, 2015, 2017, or set envment variable VisualStudioVersion")
        endif()
    endif()
    SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd4819")  #删除不是GBK字符的警告  
    
    # This option is to enable the /MP switch for Visual Studio 2005 and above compilers
    OPTION(WIN32_USE_MP "Set to ON to build OpenSceneGraph with the /MP option (Visual Studio 2005 and above)." ON)
    MARK_AS_ADVANCED(WIN32_USE_MP)
    IF(WIN32_USE_MP)
        SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /MP")
    ENDIF(WIN32_USE_MP)
    
    if(Qt5_VERSION VERSION_LESS "5.7.0")
        SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /SUBSYSTEM:WINDOWS\",5.01\"")
    endif() 
    ADD_DEFINITIONS(-DWINDOWS)
ELSEIF(MINGW)
    SET(RABBITIM_SYSTEM windows)
    SET(TOOLCHAIN_NAME windows_mingw)
    SET(RABBIT_TOOLCHAIN_VERSION $ENV{RABBIT_TOOLCHAIN_VERSION})
    if(NOT RABBIT_TOOLCHAIN_VERSION)
        SET(RABBIT_TOOLCHAIN_VERSION 530)
    endif()
    # Windows compatibility
    SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-subsystem,windows")
    # Statically link with libgcc
    #SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static -static-libgcc -static-libstdc++ ")
    ADD_DEFINITIONS(-DWINDOWS)
ELSEIF(ANDROID)
    SET(RABBITIM_SYSTEM android)
    SET(TOOLCHAIN_NAME android)
    SET(BUILD_SHARED_LIBS OFF CACHE FORCE) #android用静态编译  
    ADD_DEFINITIONS(-DMOBILE)
    INCLUDE_DIRECTORIES(${CMAKE_SOURCE_DIR}/android/jni)
    FIND_PACKAGE(Qt5AndroidExtras REQUIRED)
    SET(QT_LIBRARIES ${QT_LIBRARIES} ${Qt5AndroidExtras_LIBRARIES})
    #SET(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} -Wno-psabi -march=armv7-a -mfloat-abi=softfp -mfpu=vfp -ffunction-sections -funwind-tables -fstack-protector -fno-short-enums  -Wa,--noexecstack -gdwarf-2 -marm -fno-omit-frame-pointer -Wall -Wno-psabi -W -fPIE)
    SET(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--no-undefined -Wl,-z,noexecstack -shared --sysroot=${ANDROID_SYSROOT}")
ELSE(LINUX OR UNIX)
    SET(RABBITIM_SYSTEM unix)
    SET(TOOLCHAIN_NAME unix)
    ADD_DEFINITIONS(-DUNIX)
ENDIF()
IF(NOT DEFINED THIRD_LIBRARY_PATH)
    SET(THIRD_LIBRARY_PATH $ENV{THIRD_LIBRARY_PATH})
ENDIF()
IF(NOT DEFINED THIRD_LIBRARY_PATH)
    SET(THIRD_LIBRARY_PATH ${CMAKE_SOURCE_DIR}/ThirdLibrary/${TOOLCHAIN_NAME}${RABBIT_TOOLCHAIN_VERSION}_${RABBITIM_ARCHITECTURE}_qt${Qt5_VERSION}_${RABBIT_CONFIG}) #第三方开发包目录
ENDIF()
IF(NOT BUILD_SHARED_LIBS AND EXISTS "${THIRD_LIBRARY_PATH}_static")
    SET(THIRD_LIBRARY_PATH ${THIRD_LIBRARY_PATH}_static)
ENDIF()
INCLUDE_DIRECTORIES(${CMAKE_SOURCE_DIR} 
    ${CMAKE_SOURCE_DIR}/Widgets/FrmCustom
    ${CMAKE_SOURCE_DIR}/common
    ${THIRD_LIBRARY_PATH}/include)        #第三方包含头文件目录
SET(THIRD_LIB_DIR ${THIRD_LIBRARY_PATH}/lib) #第三方库目录
LINK_DIRECTORIES(${THIRD_LIB_DIR})
ADD_DEFINITIONS(-DRABBITIM_SYSTEM="${RABBITIM_SYSTEM}")

#pkgconfig模块
#IF(MINGW)
#    set(ENV{PKG_CONFIG_PATH} "${THIRD_LIB_DIR}/pkgconfig" ENV{PKG_CONFIG_PATH})
#ELSEIF(ANDROID)
#    set(ENV{PKG_CONFIG_PATH} "${THIRD_LIB_DIR}/pkgconfig")
#    set(ENV{PKG_CONFIG_SYSROOT_DIR} "${THIRD_LIBRARY_PATH}")
#    set(ENV{PKG_CONFIG_LIBDIR} "${THIRD_LIB_DIR}/pkgconfig")
#ELSE()
#    set(ENV{PKG_CONFIG_PATH} "${THIRD_LIB_DIR}/pkgconfig" ENV{PKG_CONFIG_PATH})
#ENDIF()

#设置 find_package 搜索目录,(find_XXX.cmake)
SET(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake ${THIRD_LIBRARY_PATH} ${CMAKE_MODULE_PATH})
FIND_PACKAGE(PkgConfig)
#允许 pkg-config 在 CMAKE_PREFIX_PATH 中搜索库
SET(PKG_CONFIG_USE_CMAKE_PREFIX_PATH TRUE)
#设置库的搜索路径
SET(CMAKE_PREFIX_PATH ${THIRD_LIB_DIR}/pkgconfig ${THIRD_LIB_DIR} ${THIRD_LIBRARY_PATH} ${CMAKE_PREFIX_PATH})
IF(ANDROID)
    SET(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} ${THIRD_LIBRARY_PATH}/sdk/native/jni)
    SET(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} ${THIRD_LIBRARY_PATH}/libs/${ANDROID_ABI}/pkgconfig)
    SET(THIRD_LIB_DIR ${THIRD_LIB_DIR} ${THIRD_LIBRARY_PATH}/libs/${ANDROID_ABI})
ENDIF(ANDROID)
message("CMAKE_PREFIX_PATH:${CMAKE_PREFIX_PATH}")
