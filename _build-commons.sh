#!/usr/bin/env bash

initTargetDistroRid()
{
    source ${__ProjectDir}/init-distro-rid.sh

    local passedRootfsDir=""

    # Only pass ROOTFS_DIR if cross is specified.
    if [ "$__CrossBuild" = 1 ]; then
        passedRootfsDir=${ROOTFS_DIR}
    fi

    initDistroRidGlobal "$__BuildOS" "$__BuildArch" "$__PortableBuild" "$passedRootfsDir"
}

isMSBuildOnNETCoreSupported()
{
    __isMSBuildOnNETCoreSupported=$__msbuildonunsupportedplatform

    if [ "$__isMSBuildOnNETCoreSupported" = 1 ]; then
        return
    fi

    if [ "$__SkipManaged" = 1 ]; then
        __isMSBuildOnNETCoreSupported=0
        return
    fi

    if [ "$__HostOS" = "Linux" ] && { [ "$__HostArch" = "x64" ] || [ "$__HostArch" = "arm" ] || [ "$__HostArch" = "arm64" ]; }; then
        __isMSBuildOnNETCoreSupported=1
    elif [ "$__HostArch" = "x64" ] && { [ "$__HostOS" = "OSX" ] || [ "$__HostOS" = "FreeBSD" ]; }; then
        __isMSBuildOnNETCoreSupported=1
    fi
}

usage()
{
    echo "Usage: $0 <options>"
    echo ""
    echo "Common Options:"
    echo ""
    echo "BuildArch can be: -x64, -x86, -arm, -armel, -arm64"
    echo "BuildType can be: -debug, -checked, -release"
    echo "-bindir - output directory (defaults to $__ProjectRoot/bin)"
    echo "-clang - optional argument to build using clang in PATH (default)."
    echo "-clangx.y - optional argument to build using clang version x.y."
    echo "-cmakeargs - user-settable additional arguments passed to CMake."
    echo "-configureonly - do not perform any builds; just configure the build."
    echo "-coverage - optional argument to enable code coverage build (currently supported only for Linux and OSX)."
    echo "-cross - optional argument to signify cross compilation,"
    echo "       - will use ROOTFS_DIR environment variable if set."
    echo "-gcc - optional argument to build using gcc in PATH."
    echo "-gccx.y - optional argument to build using gcc version x.y."
    echo "-msbuildonunsupportedplatform - build managed binaries even if distro is not officially supported."
    echo "-ninja - target ninja instead of GNU make"
    echo "-numproc - set the number of build processes."
    echo "-portablebuild - pass -portablebuild=false to force a non-portable build."
    echo "-skipconfigure - skip build configuration."
    echo "-skipmanaged - do not build managed components."
    echo "-skipnative - do not build native components."
    echo "-skipgenerateversion - disable version generation even if MSBuild is supported."
    echo "-verbose - optional argument to enable verbose build output."
    echo ""
    echo "Additional Options:"
    echo ""
    for i in ${!usage_list[@]}; do
        echo "${usage_list[${i}]}"
    done
    echo ""
    exit 1
}

# Use uname to determine what the CPU is.
CPUName=$(uname -p)

# Some Linux platforms report unknown for platform, but the arch for machine.
if [ "$CPUName" = "unknown" ]; then
    CPUName=$(uname -m)
fi

case $CPUName in
    aarch64)
        __BuildArch=arm64
        __HostArch=arm64
        ;;

    amd64)
        __BuildArch=x64
        __HostArch=x64
        ;;

    armv7l)
        echo "Unsupported CPU $CPUName detected, build might not succeed!"
        __BuildArch=arm
        __HostArch=arm
        ;;

    i686)
        echo "Unsupported CPU $CPUName detected, build might not succeed!"
        __BuildArch=x86
        __HostArch=x86
        ;;

    x86_64)
        __BuildArch=x64
        __HostArch=x64
        ;;

    *)
        echo "Unknown CPU $CPUName detected, configuring as if for x64"
        __BuildArch=x64
        __HostArch=x64
        ;;
esac

# Use uname to determine what the OS is.
OSName=$(uname -s)
case $OSName in
    Darwin)
        __BuildOS=OSX
        __HostOS=OSX
        ;;

    FreeBSD)
        __BuildOS=FreeBSD
        __HostOS=FreeBSD
        ;;

    Linux)
        __BuildOS=Linux
        __HostOS=Linux
        ;;

    NetBSD)
        __BuildOS=NetBSD
        __HostOS=NetBSD
        ;;

    OpenBSD)
        __BuildOS=OpenBSD
        __HostOS=OpenBSD
        ;;

    SunOS)
        __BuildOS=SunOS
        __HostOS=SunOS
        ;;

    *)
        echo "Unsupported OS $OSName detected, configuring as if for Linux"
        __BuildOS=Linux
        __HostOS=Linux
        ;;
esac

while :; do
    if [ $# -le 0 ]; then
        break
    fi

    lowerI="$(echo "$1" | awk '{print tolower($0)}')"
    case $lowerI in
        -\?|-h|--help)
            usage
            exit 1
            ;;

        arm|-arm)
            __BuildArch=arm
            ;;

        arm64|-arm64)
            __BuildArch=arm64
            ;;

        armel|-armel)
            __BuildArch=armel
            ;;

        bindir|-bindir)
            if [ -n "$2" ]; then
                __RootBinDir="$2"
                if [ ! -d "$__RootBinDir" ]; then
                    mkdir "$__RootBinDir"
                fi
                __RootBinParent=$(dirname "$__RootBinDir")
                __RootBinName=${__RootBinDir##*/}
                __RootBinDir="$(cd "$__RootBinParent" &>/dev/null && printf %s/%s "$PWD" "$__RootBinName")"
                shift
            else
                echo "ERROR: 'bindir' requires a non-empty option argument"
                exit 1
            fi
            ;;

        checked|-checked)
            __BuildType=Checked
            ;;

        ci|-ci)
            __ArcadeScriptArgs="--ci"
            __ErrMsgPrefix="##vso[task.logissue type=error]"
            ;;

        clang3.5|-clang3.5)
            __ClangMajorVersion=3
            __ClangMinorVersion=5
            ;;

        clang3.6|-clang3.6)
            __ClangMajorVersion=3
            __ClangMinorVersion=6
            ;;

        clang3.7|-clang3.7)
            __ClangMajorVersion=3
            __ClangMinorVersion=7
            ;;

        clang3.8|-clang3.8)
            __ClangMajorVersion=3
            __ClangMinorVersion=8
            ;;

        clang3.9|-clang3.9)
            __ClangMajorVersion=3
            __ClangMinorVersion=9
            ;;

        clang4.0|-clang4.0)
            __ClangMajorVersion=4
            __ClangMinorVersion=0
            ;;

        clang5.0|-clang5.0)
            __ClangMajorVersion=5
            __ClangMinorVersion=0
            ;;

        clang6.0|-clang6.0)
            __ClangMajorVersion=6
            __ClangMinorVersion=0
            ;;

        clang7|-clang7)
            __ClangMajorVersion=7
            __ClangMinorVersion=
            ;;

        clang8|-clang8)
            __ClangMajorVersion=8
            __ClangMinorVersion=
            ;;

        clang9|-clang9)
            __ClangMajorVersion=9
            __ClangMinorVersion=
            ;;

        cmakeargs|-cmakeargs)
            if [ -n "$2" ]; then
                __cmakeargs="$__cmakeargs $2"
                shift
            else
                echo "ERROR: 'cmakeargs' requires a non-empty option argument"
                exit 1
            fi
            ;;

        configureonly|-configureonly)
            __ConfigureOnly=1
            __SkipMSCorLib=1
            __SkipNuget=1
            ;;

        coverage|-coverage)
            __CodeCoverage=Coverage
            ;;

        cross|-cross)
            __CrossBuild=1
            ;;

        debug|-debug)
            __BuildType=Debug
            ;;

        gcc5|-gcc5)
            __GccMajorVersion=5
            __GccMinorVersion=
            __GccBuild=1
            ;;

        gcc6|-gcc6)
            __GccMajorVersion=6
            __GccMinorVersion=
            __GccBuild=1
            ;;

        gcc7|-gcc7)
            __GccMajorVersion=7
            __GccMinorVersion=
            __GccBuild=1
            ;;

        gcc8|-gcc8)
            __GccMajorVersion=8
            __GccMinorVersion=
            __GccBuild=1
            ;;

        gcc9|-gcc9)
            __GccMajorVersion=9
            __GccMinorVersion=
            __GccBuild=1
            ;;

        gcc|-gcc)
            __GccMajorVersion=
            __GccMinorVersion=
            __GccBuild=1
            ;;

        msbuildonunsupportedplatform|-msbuildonunsupportedplatform)
            __msbuildonunsupportedplatform=1
            ;;

        ninja|-ninja)
            __UseNinja=1
            ;;

        numproc|-numproc)
            if [ -n "$2" ]; then
              __NumProc="$2"
              shift
            else
              echo "ERROR: 'numproc' requires a non-empty option argument"
              exit 1
            fi
            ;;

        portablebuild=false|-portablebuild=false)
            __PortableBuild=0
            ;;

        rebuild|-rebuild)
            __RebuildTests=1
            ;;

        release|-release)
            __BuildType=Release
            ;;

        skipconfigure|-skipconfigure)
            __SkipConfigure=1
            ;;

        skipgenerateversion|-skipgenerateversion)
            __SkipGenerateVersion=1
            ;;

        skipmanaged|-skipmanaged)
            __SkipManaged=1
            __BuildTestWrappers=0
            ;;

        skipnative|-skipnative)
            __SkipNative=1
            __SkipCoreCLR=1
            __CopyNativeProjectsAfterCombinedTestBuild=false
            ;;

        verbose|-verbose)
            __VerboseBuild=1
            ;;

        x86|-x86)
            __BuildArch=x86
            ;;

        x64|-x64)
            __BuildArch=x64
            ;;

        *)
            handle_arguments "$1"
            ;;
    esac

    shift
done

# Get the number of processors available to the scheduler
# Other techniques such as `nproc` only get the number of
# processors available to a single process.
platform=$(uname)
if [ "$platform" = "FreeBSD" ]; then
  __NumProc=$(sysctl hw.ncpu | awk '{ print $2+1 }')
elif [ "$platform" = "NetBSD" ]; then
  __NumProc=$(($(getconf NPROCESSORS_ONLN)+1))
elif [ "$platform" = "Darwin" ]; then
  __NumProc=$(($(getconf _NPROCESSORS_ONLN)+1))
else
  __NumProc=$(nproc --all)
fi

__CommonMSBuildArgs="/p:__BuildArch=$__BuildArch /p:__BuildType=$__BuildType /p:__BuildOS=$__BuildOS /nodeReuse:false $__OfficialBuildIdArg $__SignTypeArg $__SkipRestoreArg"

# Configure environment if we are doing a verbose build
if [ "$__VerboseBuild" = 1 ]; then
    export VERBOSE=1
    __CommonMSBuildArgs="$__CommonMSBuildArgs /v:detailed"
fi

# Set default clang version
if [ "$__ClangMajorVersion" = 0 ] && [ "$__ClangMinorVersion" = 0 ]; then
    if [ "$__BuildArch" = "arm" ] || [ "$__BuildArch" = "armel" ]; then
        __ClangMajorVersion=5
        __ClangMinorVersion=0
    else
        __ClangMajorVersion=3
        __ClangMinorVersion=9
    fi
fi
