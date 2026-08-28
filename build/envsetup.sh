CLANG_VERSION=$(${ANDROID_BUILD_TOP}/vendor/voltage/tools/get_clang_version.py)
export LLVM_AOSP_PREBUILTS_VERSION="${CLANG_VERSION}"

RUST_VERSION=$(grep 'RustDefaultVersion =' ${ANDROID_BUILD_TOP}/build/soong/rust/config/global.go | awk '{print $3}' | awk -F '"' '{print $2}')
export RUST_AOSP_PREBUILTS_VERSION="${RUST_VERSION}"

function brunch()
{
    local args=()
    local delta=false
    for arg in "$@"; do
        if [ "$arg" = "--delta" ]; then
            delta=true
        else
            args+=("$arg")
        fi
    done

    breakfast "${args[@]}"
    if [ $? -eq 0 ]; then
        if [ "$delta" = "true" ]; then
            mka bacon --delta
        else
            mka bacon
        fi
    else
        echo "No such item in brunch menu. Try 'breakfast'"
        return 1
    fi
    return $?
}

function breakfast()
{
    target=$1
    local variant=$2
    source ${ANDROID_BUILD_TOP}/vendor/custom/vars/aosp_target_release

    if [ $# -eq 0 ]; then
        # No arguments, so let's have the full menu
        lunch
    else
        if [[ "$target" =~ -(user|userdebug|eng)$ ]]; then
            # A buildtype was specified, assume a full device name
            lunch $target
        else
            # This is probably just the ASCP OS model name
            if [ -z "$variant" ]; then
                variant="userdebug"
            fi

            lunch $target-$aosp_target_release-$variant
        fi
    fi
    return $?
}

alias bib=breakfast

function aospremote()
{
    local T=`git rev-parse --show-toplevel 2> /dev/null`
    if [ -z "$T" ]
    then
        echo "Git repository not found. Please run this from the directory of the Android repository you wish to set up."
        return 1
    fi
    git remote rm aosp 2> /dev/null

    if [ -f "$T/.gitupstream" ]; then
        local REMOTE=$(cat "$T/.gitupstream" | cut -d ' ' -f 1)
        git remote add aosp ${REMOTE}
    else
        local PROJECT=$(pwd -P | sed -e "s#$ANDROID_BUILD_TOP\/##; s#-caf.*##; s#\/default##")
        # Google moved the repo location in Oreo
        if [ $PROJECT = "build/make" ]
        then
            PROJECT="build"
        fi
        if (echo $PROJECT | grep -qv "^device")
        then
            local PFX="platform/"
        fi
        git remote add aosp https://android.googlesource.com/$PFX$PROJECT
    fi
    echo "Remote 'aosp' created"
}

function cloremote()
{
    local T=`git rev-parse --show-toplevel 2> /dev/null`
    if [ -z "$T" ]
    then
        echo "Git repository not found. Please run this from the directory of the Android repository you wish to set up."
        return 1
    fi
    git remote rm clo 2> /dev/null

    if [ -f "$T/.gitupstream" ]; then
        local REMOTE=$(cat "$T/.gitupstream" | cut -d ' ' -f 1)
        git remote add clo ${REMOTE}
    else
        local PROJECT=$(pwd -P | sed -e "s#$ANDROID_BUILD_TOP\/##; s#-caf.*##; s#\/default##")
        # Google moved the repo location in Oreo
        if [ $PROJECT = "build/make" ]
        then
            PROJECT="build_repo"
        fi
        if [[ $PROJECT =~ "qcom/opensource" ]];
        then
            PROJECT=$(echo $PROJECT | sed -e "s#qcom\/opensource#qcom-opensource#")
        fi
        if (echo $PROJECT | grep -qv "^device")
        then
            local PFX="platform/"
        fi
        git remote add clo https://git.codelinaro.org/clo/la/$PFX$PROJECT
    fi
    echo "Remote 'clo' created"
}

function githubremote()
{
    if ! git rev-parse --git-dir &> /dev/null
    then
        echo ".git directory not found. Please run this from the root directory of the Android repository you wish to set up."
        return 1
    fi
    git remote rm github 2> /dev/null
    local REMOTE=$(git config --get remote.aosp.projectname)

    if [ -z "$REMOTE" ]
    then
        REMOTE=$(git config --get remote.clo.projectname)
    fi

    local PROJECT=$(echo $REMOTE | sed -e "s#platform/#android/#g; s#/#_#g")

    git remote add github https://github.com/ASCP-Project/$PROJECT
    echo "Remote 'github' created"
}

function privateremote()
{
    if ! git rev-parse --git-dir &> /dev/null
    then
        echo ".git directory not found. Please run this from the root directory of the Android repository you wish to set up."
        return 1
    fi
    git remote rm private 2> /dev/null
    local PROJECT=$(git config --get remote.github.projectname)

    git remote add private git@github.com:$PROJECT.git
    echo "Remote 'private' created"
}

function mka() {
    local args=()
    export ASCP_DELTA_BUILD=false
    for arg in "$@"; do
        if [ "$arg" = "--delta" ]; then
            export ASCP_DELTA_BUILD=true
        else
            args+=("$arg")
        fi
    done
    m "${args[@]}"
}

function cmka() {
    local targets=()
    local delta_flag=""
    for arg in "$@"; do
        if [ "$arg" = "--delta" ]; then
            delta_flag="--delta"
        else
            targets+=("$arg")
        fi
    done

    if [ ${#targets[@]} -gt 0 ]; then
        for i in "${targets[@]}"; do
            case $i in
                bacon|otapackage|systemimage)
                    mka installclean $delta_flag
                    mka $i $delta_flag
                    ;;
                *)
                    mka clean-$i $delta_flag
                    mka $i $delta_flag
                    ;;
            esac
        done
    else
        mka clean $delta_flag
        mka $delta_flag
    fi
}

function repolastsync() {
    RLSPATH="$ANDROID_BUILD_TOP/.repo/.repo_fetchtimes.json"
    RLSLOCAL=$(date -d "$(stat -c %z $RLSPATH)" +"%e %b %Y, %T %Z")
    RLSUTC=$(date -d "$(stat -c %z $RLSPATH)" -u +"%e %b %Y, %T %Z")
    echo "Last repo sync: $RLSLOCAL / $RLSUTC"
}

function reposync() {
    repo sync -j 4 "$@"
}

function repodiff() {
    if [ -z "$*" ]; then
        echo "Usage: repodiff <ref-from> [[ref-to] [--numstat]]"
        return
    fi
    diffopts=$* repo forall -c \
      'echo "$REPO_PATH ($REPO_REMOTE)"; git diff ${diffopts} 2>/dev/null ;'
}

alias mkap='dopush mka'
alias cmkap='dopush cmka'

function sort-blobs-list() {
    T=$(gettop)
    $T/tools/extract-utils/sort-blobs-list.py $@
}

function fixup_common_out_dir() {
    common_out_dir=$(_get_build_var_cached OUT_DIR)/target/common
    target_device=$(_get_build_var_cached TARGET_DEVICE)
    common_target_out=common-${target_device}
    if [ ! -z $ASCP_FIXUP_COMMON_OUT ]; then
        if [ -d ${common_out_dir} ] && [ ! -L ${common_out_dir} ]; then
            mv ${common_out_dir} ${common_out_dir}-${target_device}
            ln -s ${common_target_out} ${common_out_dir}
        else
            [ -L ${common_out_dir} ] && rm ${common_out_dir}
            mkdir -p ${common_out_dir}-${target_device}
            ln -s ${common_target_out} ${common_out_dir}
        fi
    else
        [ -L ${common_out_dir} ] && rm ${common_out_dir}
        mkdir -p ${common_out_dir}
    fi
}

function build_kernel() {
    if [[ "${SKIP_KERNEL_BUILD}" == "true" || "${SKIP_KERNEL_BUILD}" == "1" ]]; then
        echo "Skipping kernel build"
        return
    fi
    local ascp_version="${ASCP_BASE_VERSION}"

    local target_kernel_device="$(_get_build_var_cached TARGET_KERNEL_DEVICE)"
    local target_kernel_dir="${ANDROID_BUILD_TOP}/$(_get_build_var_cached TARGET_KERNEL_DIR)"
    local target_kernel_source="$(_get_build_var_cached TARGET_KERNEL_PLATFORM_SOURCE)"

    local KERNEL_BUILD_TOP="${ANDROID_BUILD_TOP}/out-kernel/${target_kernel_source}"

    # Make sure we have the kernel source folder structure in place
    if [ ! -d "${KERNEL_BUILD_TOP}/.repo" ]; then
        echo "Kernel source ${KERNEL_BUILD_TOP} is missing, preparing folder structure"

        # Copy .repo/repo from Android tree to allow nested `repo init`
        mkdir -p "${KERNEL_BUILD_TOP}/.repo"
        cp -R "${ANDROID_BUILD_TOP}/.repo/repo" "${KERNEL_BUILD_TOP}/.repo/repo"

        # Allow custom .repo/project-objects dir
        if [ -n "${KERNEL_REPO_PROJECT_OBJECTS_DIR}" ]; then
            if [ ! -d "${KERNEL_REPO_PROJECT_OBJECTS_DIR}" ]; then
                mkdir "${KERNEL_REPO_PROJECT_OBJECTS_DIR}"
            fi
            ln -sf "${KERNEL_REPO_PROJECT_OBJECTS_DIR}" "${KERNEL_BUILD_TOP}/.repo/project-objects"
        fi

        # Allow custom .repo/projects dir
        if [ -n "${KERNEL_REPO_PROJECTS_DIR}" ]; then
            if [ ! -d "${KERNEL_REPO_PROJECTS_DIR}" ]; then
                mkdir "${KERNEL_REPO_PROJECTS_DIR}"
            fi
            ln -sf "${KERNEL_REPO_PROJECTS_DIR}" "${KERNEL_BUILD_TOP}/.repo/projects"
        fi

        # Mark as out dir to prevent build system from scanning it
        touch "${KERNEL_BUILD_TOP}/.out-dir"
    fi

    # Init, sync, remove previous build output & build kernel
    pushd "${KERNEL_BUILD_TOP}" > /dev/null
    if [[ "${SKIP_KERNEL_SYNC}" != "true" && "${SKIP_KERNEL_SYNC}" != "1" ]]; then
        echo "Syncing ${KERNEL_BUILD_TOP}"
        local target_kernel_manifest=$(echo platform_kernel_${target_kernel_source}_manifest | tr / _)
        local repo_init_args=("-b" "${ascp_version}")
        if [ -n "${ASCP_MIRROR}" ]; then
            repo_init_args+=("--reference" "${ASCP_MIRROR}")
        fi
        if [ -n "${REPO_VERSION}" ]; then
            repo_init_args+=("--repo-rev" "${REPO_VERSION}")
        fi

        yes | repo init -u https://github.com/ASCP-Project/${target_kernel_manifest}.git ${repo_init_args[@]} || [ $? -eq 141 ]
        if [ $? -ne 0 ]; then
            echo "Kernel source repo init failed"
            popd > /dev/null
            return 1
        fi
        if ! repo sync --detach --force-sync; then
            echo "Kernel source repo sync failed"
            popd > /dev/null
            return 1
        fi
    fi
    if [ -d "${KERNEL_BUILD_TOP}/out/${target_kernel_device}/dist" ]; then
        rm -rf "${KERNEL_BUILD_TOP}/out/${target_kernel_device}/dist"
    fi
    if ! ./build_"${target_kernel_device}".sh; then
        popd > /dev/null
        return 1
    fi
    popd > /dev/null

    # Remove previous kernel prebuilts
    if [ -d "${target_kernel_dir}" ]; then
        local find_args=("-maxdepth" "1" "-type" "f" "!" "-name" ".gitignore")
        # Some kernels don't generate the module lists, in which case they're
        # checked in next to the prebuilts. Don't delete what won't come back.
        if [[ "$(_get_build_var_cached TARGET_PROVIDES_STATIC_MODULE_LISTS)" == "true" ]]; then
            find_args+=("!" "-name" "*.modules.load*" "!" "-name" "*.modules.blocklist")
        fi
        find "${target_kernel_dir}" "${find_args[@]}" -delete
    fi

    # Copy the new kernel prebuilts
    mkdir -p "${target_kernel_dir}"
    cp -a "${KERNEL_BUILD_TOP}/out/${target_kernel_device}/dist/"* "${target_kernel_dir}/"
    chmod -x "${target_kernel_dir}/"*
    echo "Kernel build output copied to ${target_kernel_dir}/"
}

function generate_host_overrides() {
    export BUILD_USERNAME=android-build
    HEX=$(openssl rand -hex 8)
    ALPHA=$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 4)
    export BUILD_HOSTNAME="r-${HEX}-${ALPHA}"
    echo "BUILD_USERNAME=$BUILD_USERNAME"
    echo "BUILD_HOSTNAME=$BUILD_HOSTNAME"
}

generate_host_overrides

export SKIP_ABI_CHECKS=true

export DISABLE_STUB_VALIDATION=true