#!/bin/sh

#作者：康林
#参数:
#    $1:编译目标(android、windows_msvc、windows_mingw、unix)
#    $2:源码的位置 

#运行本脚本前,先运行 build_$1_envsetup.sh 进行环境变量设置,需要先设置下面变量:
#   RABBITIM_BUILD_TARGERT   编译目标（android、windows_msvc、windows_mingw、unix)
#   RABBITIM_BUILD_PREFIX=`pwd`/../${RABBITIM_BUILD_TARGERT}  #修改这里为安装前缀
#   RABBITIM_BUILD_SOURCE_CODE    #源码目录
#   RABBITIM_BUILD_CROSS_PREFIX     #交叉编译前缀
#   RABBITIM_BUILD_CROSS_SYSROOT  #交叉编译平台的 sysroot

set -e
HELP_STRING="Usage $0 PLATFORM (android|windows_msvc|windows_mingw|unix) [SOURCE_CODE_ROOT_DIRECTORY]"

case $1 in
    android|windows_msvc|windows_mingw|unix)
    RABBITIM_BUILD_TARGERT=$1
    ;;
    *)
    echo "${HELP_STRING}"
    exit 1
    ;;
esac

if [ -z "${RABBITIM_BUILD_PREFIX}" ]; then
    echo ". `pwd`/build_envsetup_${RABBITIM_BUILD_TARGERT}.sh"
    . `pwd`/build_envsetup_${RABBITIM_BUILD_TARGERT}.sh
fi

if [ -n "$2" ]; then
    RABBITIM_BUILD_SOURCE_CODE=$2
else
    RABBITIM_BUILD_SOURCE_CODE=${RABBITIM_BUILD_PREFIX}/../src/libcurl
fi

CUR_DIR=`pwd`

#下载源码:
if [ ! -d ${RABBITIM_BUILD_SOURCE_CODE} ]; then
    if [ "TRUE" = "$RABBITIM_USE_REPOSITORIES" ]; then
        echo "git clone git://github.com/bagder/curl.git ${RABBITIM_BUILD_SOURCE_CODE}"
        #git clone --branch=curl-7_41_0 git://github.com/bagder/curl.git ${RABBITIM_BUILD_SOURCE_CODE}
        git clone git://github.com/bagder/curl.git ${RABBITIM_BUILD_SOURCE_CODE}
    else
        CUR_FILE=curl-7.41.0
        echo "wget http://curl.haxx.se/download/${CUR_FILE}.tar.gz"
        mkdir -p ${RABBITIM_BUILD_SOURCE_CODE}
        cd ${RABBITIM_BUILD_SOURCE_CODE}
        wget http://curl.haxx.se/download/${CUR_FILE}.tar.gz
        tar xzf ${CUR_FILE}.tar.gz
        mv ${CUR_FILE} ..
        rm -fr *
        cd ..
        mv -f ${CUR_FILE} ${RABBITIM_BUILD_SOURCE_CODE}
    fi
fi

cd ${RABBITIM_BUILD_SOURCE_CODE}

if [ "$RABBITIM_CLEAN" ]; then
    if [ -d ".git" ]; then
        git clean -xdf
    fi
fi

if [ ! -f configure ]; then
    echo "sh buildconf"
    if [ "${RABBITIM_BUILD_TARGERT}" = "windows_msvc" ]; then
        ./buildconf.bat
    else
        ./buildconf
    fi
fi

if [ "${RABBITIM_BUILD_TARGERT}" = "windows_msvc" ]; then
    if [ -n "$RABBITIM_CLEAN" ]; then
        rm -fr builds
    fi
else
    mkdir -p build_${RABBITIM_BUILD_TARGERT}
    cd build_${RABBITIM_BUILD_TARGERT}
    if [ -n "$RABBITIM_CLEAN" ]; then
        rm -fr *
    fi
fi

echo ""
echo "RABBITIM_BUILD_TARGERT:${RABBITIM_BUILD_TARGERT}"
echo "RABBITIM_BUILD_SOURCE_CODE:$RABBITIM_BUILD_SOURCE_CODE"
echo "CUR_DIR:`pwd`"
echo "RABBITIM_BUILD_PREFIX:$RABBITIM_BUILD_PREFIX"
echo "RABBITIM_BUILD_HOST:$RABBITIM_BUILD_HOST"
echo "RABBITIM_BUILD_CROSS_HOST:$RABBITIM_BUILD_CROSS_HOST"
echo "RABBITIM_BUILD_CROSS_PREFIX:$RABBITIM_BUILD_CROSS_PREFIX"
echo "RABBITIM_BUILD_CROSS_SYSROOT:$RABBITIM_BUILD_CROSS_SYSROOT"
echo "RABBITIM_BUILD_STATIC:$RABBITIM_BUILD_STATIC"
echo ""

echo "configure ..."

if [ "$RABBITIM_BUILD_STATIC" = "static" ]; then
    CONFIG_PARA="--enable-static --disable-shared"
else
    CONFIG_PARA="--disable-static --enable-shared"
fi
case ${RABBITIM_BUILD_TARGERT} in
    android)
        CONFIG_PARA="CC=${RABBITIM_BUILD_CROSS_PREFIX}gcc --disable-shared -enable-static --host=${RABBITIM_BUILD_CROSS_HOST}"
        CFLAGS="-march=armv7-a -mfpu=neon --sysroot=${RABBITIM_BUILD_CROSS_SYSROOT}"
        CPPFLAGS="-march=armv7-a -mfpu=neon --sysroot=${RABBITIM_BUILD_CROSS_SYSROOT}"
        ;;
    unix)
        CONFIG_PARA="${CONFIG_PARA} --with-gnu-ld --enable-sse"
        ;;
    windows_msvc)
        #cmake .. -G"Visual Studio 12 2013" \
        #    -DCMAKE_INSTALL_PREFIX="$RABBITIM_BUILD_PREFIX" \
        #    -DCMAKE_BUILD_TYPE="Release" \
        #    -DBUILD_CURL_TESTS=OFF \
        #    -DCURL_STATICLIB=OFF
        #;;
        cd ${RABBITIM_BUILD_SOURCE_CODE}
        ./buildconf.bat
        cd winbuild
        if [ "$RABBITIM_BUILD_STATIC" = "static" ]; then
            MODE=static
        else
            MODE=dll
        fi
        nmake -f Makefile.vc mode=$MODE VC=12 WITH_DEVEL=$RABBITIM_BUILD_PREFIX
        cp -fr ${RABBITIM_BUILD_SOURCE_CODE}/builds/libcurl-vc12-x86-release-${MODE}-ipv6-sspi-winssl/* ${RABBITIM_BUILD_PREFIX}
        cd $CUR_DIR
        exit 0
        ;;
    windows_mingw)
        case `uname -s` in
            Linux*|Unix*)
                CONFIG_PARA="${CONFIG_PARA}  CC=${RABBITIM_BUILD_CROSS_PREFIX}gcc --host=${RABBITIM_BUILD_CROSS_HOST} --enable-sse"
                ;;
            *)
            ;;
        esac
        ;;
    *)
        echo "${HELP_STRING}"
        cd $CUR_DIR
        exit 3
        ;;
esac

echo "make install"
echo "pwd:`pwd`"
CONFIG_PARA="${CONFIG_PARA} --prefix=$RABBITIM_BUILD_PREFIX --disable-debug --disable-curldebug --disable-manual"
CONFIG_PARA="${CONFIG_PARA} --with-ssl=$RABBITIM_BUILD_PREFIX"
echo "../configure ${CONFIG_PARA} CFLAGS=\"${CFLAGS=}\" CPPFLAGS=\"${CPPFLAGS}\""
../configure ${CONFIG_PARA} CFLAGS="${CFLAGS}" CPPFLAGS="${CPPFLAGS}"

make ${RABBITIM_MAKE_JOB_PARA} && make install

cd $CUR_DIR