#!/usr/bin/env bash

# Copyright (C) 2024 MediaTek Inc. All rights reserved.
# Author: Weijie Gao <weijie.gao@mediatek.com>
# Autobuild framework for OpenWrt

export NO_JEVENTS=1

# Autobuild script base directory
ab_root="$(dirname "$(readlink -f "$0")")"

. ${ab_root}/scripts/log.sh
. ${ab_root}/scripts/list.sh
. ${ab_root}/scripts/kconfig.sh
. ${ab_root}/scripts/openwrt_helpers.sh
. ${ab_root}/scripts/ftsnap.sh
. ${ab_root}/scripts/ab-common.sh

# Command line processing

## Parse autobuild branch name
ab_branch=
ab_branch_names=
ab_branch_level=0

if autobuild_branch_name_check "${1}"; then
	canonicalize_autobuild_branch_name "${1}" ab_branch_names ab_branch
	shift
fi

## Stages
ab_stages="prepare build release"
do_menuconfig=
do_help=
do_list=
do_clean=
do_fullclean=

if list_find ab_stages "${1}"; then
	ab_stages="${1}"
	shift
elif test x"${1}" = x"sdk_release"; then
	ab_stages="prepare sdk_release"
	shift
elif test x"${1}" = x"menuconfig"; then
	ab_stages="prepare menuconfig"
	do_menuconfig=1
	shift
elif test x"${1}" = x"help"; then
	ab_stages="help"
	do_help=1
	shift
elif test x"${1}" = x"list"; then
	do_list=1
	shift
elif test x"${1}" = x"clean"; then
	do_clean=1
	shift
elif test x"${1}" = x"fullclean"; then
	do_clean=1
	do_fullclean=1
	shift
fi

## Options
__logged_args=()
for arg in "$@"; do
	if expr index ${arg} '=' 2>&1 >/dev/null; then
		name=${arg%%=*}
		value=${arg#*=}

		eval ${name}=\"\${value}\"
		eval ${name}_set=yes

		__logged_args[${#__logged_args[@]}]="${name}=\"${value}\""
	else
		eval ${arg}_set=yes

		__logged_args[${#__logged_args[@]}]="${arg}"
	fi
done

IFS=$'\n' __sorted_args=($(sort <<< "${__logged_args[*]}")); unset IFS
IFS=' ' ab_cmdline="${__logged_args[@]}"; unset IFS

# Enable debugging log?
if test x"${debug_set}" = x"yes"; then
	enable_log_debug
fi

# Enable logging to file?
if test x"${log_file_set}" = x"yes"; then
	log_file_merge=

	[ x"${log_file_merge_set}" = x"yes" ] && log_file_merge=1

	set_log_file_prefix "${log_file}" ${log_file_merge}
fi

# OK, do list here if required
if test x"${do_list}" = x"1"; then
	list_all_autobuild_branches
	exit 0
fi

openwrt_root="$(pwd)"

if ! is_openwrt_build_root "${openwrt_root}"; then
	log_err "${openwrt_root} is not a OpenWrt root directory."
	log_err "The autobuild script must be called from within the OpenWrt root directory."
	exit 1
fi

# OpenWrt branch (master, 21.02, ...)
openwrt_branch=$(openwrt_get_branch)

if test -z "${openwrt_branch}"; then
	log_err "Failed to get OpenWrt's branch"
	exit 1
else
	log_info "OpenWrt's branch is ${openwrt_branch}"
fi

# Temporary directory for storing configs and intermediate files
ab_tmp="${openwrt_root}/.ab"

# Default release directory
ab_bin_release="${openwrt_root}/autobuild_release"

# Build autobuild tools
make --no-print-directory -s -C "${ab_root}/tools"

# OK, do clean here if required
if test x"${do_clean}" = x"1"; then
	if ! git status >/dev/null; then
		log_warn "The clean stage can only be applied if the OpenWrt source is managed by Git."
		exit 1
	fi

	if test x"${do_fullclean}" = x"1"; then
		exec_log "rm -rf \"${openwrt_root}/feeds\""
		exec_log "rm -rf \"${openwrt_root}/package/feeds\""
		exec_log "rm -rf \"${openwrt_root}/tmp\""
		exec_log "rm -rf \"${openwrt_root}/log\""
		exec_log "git -C \"${openwrt_root}\" checkout ."
		exec_log "git -C \"${openwrt_root}\" clean -f -d -e autobuild"

		__residue_files=$(git -C ${openwrt_root} ls-files -m -o -x autobuild --exclude-standard)

		for __f in ${__residue_files}; do
			exec_log "rm -rf \"${openwrt_root}/${__f}\""
		done

		exit 0
	fi

	ftsnap_prepare

	exec_log "git -C \"${openwrt_root}\" checkout ."
	exec_log "git -C \"${openwrt_root}\" clean -f -d -e autobuild -e .ab"

	__residue_files=$(git -C ${openwrt_root} ls-files -m -o -x .ab -x autobuild --exclude-standard)

	for __f in ${__residue_files}; do
		exec_log "rm -rf \"${openwrt_root}/${__f}\""
	done

	# clean feeds
	for __feed in $(openwrt_avail_feeds); do
		exec_log "git -C \"${openwrt_root}/feeds/${__feed}\" checkout ."
		exec_log "git -C \"${openwrt_root}/feeds/${__feed}\" clean -f -d"
	done

	# Remove everything in .ab/ except the keep folder
	if test -d "${ab_tmp}"; then
		exec_log "find ${ab_tmp} -mindepth 1 -maxdepth 1 ! -name keep -exec rm -rf {} \;"
	fi

	exit 0
fi

# Check if we need prepare for build stage
if list_find ab_stages build; then
	if test \( ! -f "${ab_tmp}/branch_name" \) -o -f "${ab_tmp}/.stamp.menuconfig"; then
		list_add_before_unique ab_stages build prepare
	fi
fi

# Check for prepare stage
if list_find ab_stages prepare; then
	if test -f "${ab_tmp}/branch_name"; then
		# If prepare stage has been done before, check whether clean is required

		if test -z "${do_menuconfig}" -a -f "${ab_tmp}/.stamp.menuconfig"; then
			log_warn "This OpenWrt source code has already been prepared for menuconfig."
			log_warn "Please call \`${0} clean' first."
			exit 1
		fi

		if test -n "${do_menuconfig}" -a ! -f "${ab_tmp}/.stamp.menuconfig"; then
			log_warn "This OpenWrt source code has already been prepared, but not for menuconfig."
			log_warn "Please call \`${0} clean' first."
			exit 1
		fi

		last_ab_branch=$(cat "${ab_tmp}/branch_name")

		if test -n "${ab_branch}"; then
			if test x"${ab_branch}" != x"${last_ab_branch}"; then
				log_warn "Autobuild branch name has changed."
				log_warn "Please call \`${0} clean' first."
				exit 1
			fi

			if test -z "${do_menuconfig}"; then
				last_ab_cmdline=$(cat "${ab_tmp}/cmdline")

				if test x"${ab_cmdline}" != x"${last_ab_cmdline}"; then
					log_warn "Autobuild configuration has changed."
					log_warn "Please call \`${0} clean' first."
					exit 1
				fi
			fi

			# Configuration unchanged
		else
			# Read previous configuration
			canonicalize_autobuild_branch_name "${last_ab_branch}" ab_branch_names ab_branch
		fi

		# prepare stage is not needed
		list_del ab_stages prepare
	else
		if test -z "${ab_branch}" -a x"${do_help}" != x"1"; then
			log_err "Autobuild branch name is invalid or not specified."
			print_text   "Quick start:"
			print_text   "- To show detailed help:"
			log_info_raw "  ${0} help"
			print_text   "- To start full build for a branch (<branch-name> example: mtxxxx-mtxxxx-xxx):"
			log_info_raw "  ${0} <branch-name>"
			print_text   "- To continue current build:"
			log_info_raw "  ${0} build"
			print_text   "- To clean everything under OpenWrt source tree:"
			log_info_raw "  ${0} clean"
			print_text   "- To start menuconfig and update defconfig for specified branch:"
			log_info_raw "  ${0} <branch-name> menuconfig"
			print_text   "- To list all available branch names:"
			log_info_raw "  ${0} <branch-name> list"
			exit 1
		fi
	fi
else
	if test -z "${ab_branch}" -a -f "${ab_tmp}/branch_name"; then
		last_ab_branch=$(cat "${ab_tmp}/branch_name")

		# Read previous configuration
		canonicalize_autobuild_branch_name "${last_ab_branch}" ab_branch_names ab_branch
	fi
fi

## Fill branch names
ab_branch_level=${#ab_branch_names[@]}
ab_branch_platform=${ab_branch_names[0]}
ab_branch_wifi=${ab_branch_names[1]}
ab_branch_sku=${ab_branch_names[2]}
ab_branch_variant=${ab_branch_names[3]}

## Set and print branch configuration
[ -n "${ab_branch}" ] && log_info "Autobuild branch: ${ab_branch}"

if test -n "${ab_branch_platform}"; then
	ab_branch_level=1
	ab_platform_dir=${ab_root}/${ab_branch_platform}
	print_conf "Platform" "${ab_branch_platform}"
fi

if test -n "${ab_branch_wifi}"; then
	ab_branch_level=2
	ab_wifi_dir=${ab_platform_dir}/${ab_branch_wifi}
	print_conf "WiFi" "${ab_branch_wifi}"
fi

if test -n "${ab_branch_sku}"; then
	ab_branch_level=3
	ab_sku_dir=${ab_wifi_dir}/${ab_branch_sku}
	print_conf "SKU" "${ab_branch_sku}"
fi

if test -n "${ab_branch_variant}"; then
	ab_branch_level=4
	ab_variant_dir=${ab_sku_dir}/${ab_branch_variant}
	print_conf "Variant" "${ab_branch_variant}"
fi

# Setup global settings

## Set new binary release directory
if test x"${release_dir_set}" = x"yes"; then
	ab_bin_release="${openwrt_root}/${release_dir}"
fi

ab_bin_release="${ab_bin_release}/${ab_branch}"

## Set global directories
ab_global=${ab_root}/global

# Setup help text
help_add_line ""
help_add_line "Autobuild script for OpenWrt"
help_add_line ""
help_add_line "Usage: autobuild.sh [branch] [stage] [options...]"
help_add_line ""
help_add_line "Branch: <platform>[-<wifi>[-<sku>[-<variant>]]]"
help_add_line "  Branch is only required for prepare. It can be omitted for build/release"
help_add_line "  after a successful prepare."
help_add_line ""
help_add_line "Stages:"
help_add_line "  (If stage is not specified, default will be \"prepare/build/release\")"
help_add_line "  prepare     - Prepare the OpenWrt source code."
help_add_line "                Do patching, copying/deleting files."
help_add_line "                Once prepared, clean must be done before another prepare."
help_add_line "  build       - Do actual build."
help_add_line "  release     - Collect built binary files only."
help_add_line "  sdk_release - Do source code release. MediaTek internal use only."
help_add_line "  menuconfig  - Do menuconfig for specified branch. defconfig of this branch"
help_add_line "                will be updated."
help_add_line "  clean       - Clean all modified/untraced files/directories from OpenWrt"
help_add_line "                source code but keep filetime cache to reduce build time"
help_add_line "                for subsequent prepare/build."
help_add_line "  fullclean   - Do normal clean and then remove feeds and filetime cache as"
help_add_line "                well."
help_add_line "  list        - List all available branch names."
help_add_line "  help        - Show this help."
help_add_line ""
help_add_line "Options:"
help_add_line "  The options can be <key>=<value>, or just simple <key>."
help_add_line "  log_file=<file> - Enable log output to file."
help_add_line "  log_file_merge - Log stdout and stderr to one file."
help_add_line "  debug - Enable debug log output."
help_add_line "  release_dir=<dir> - Override default release directory."
help_add_line "    Default directory is 'autobuild_release' under OpenWrt's source directory."
help_add_line "  sync_config - When used with menuconfig, .config will be updated with"
help_add_line "    current branch defconfigs before starting menuconfig"

# Include branch rules (the rule is child level overriding parent level)
. "${ab_root}/rules"
[ -f "${ab_global}/${openwrt_branch}/rules" ] && . "${ab_global}/${openwrt_branch}/rules"
[ -n "${ab_platform_dir}" ] && . "${ab_platform_dir}/rules"
[ -n "${ab_wifi_dir}" ] && . "${ab_wifi_dir}/rules"
[ -n "${ab_sku_dir}" ] && . "${ab_sku_dir}/rules"
[ -n "${ab_variant_dir}" ] && . "${ab_variant_dir}/rules"

# Show help?
if test x"${do_help}" = x"1"; then
	help_print
	exit 0
fi

# Run stages
log_dbg "All stages: ${ab_stages}"

for stage in ${ab_stages}; do
	substages=$(get_substages "${stage}")

	prompt_stage "Current stage: \"${stage}\""
	log_dbg "Substages of ${stage}: ${substages}"

	for substage in ${substages}; do
		hooks=$(get_hooks "${substage}")

		prompt_stage "Current substage: \"${substage}\""

		[ -z "${hooks}" ] && hooks="${substage}"
		clean_hooks hooks

		if test -z "${hooks}"; then
			log_info "Nothing to do with substage ${substage}"
			continue
		fi

		log_dbg "Hooks of substage \"${substage}\": ${hooks}"

		for hook in ${hooks}; do
			prompt_stage "Executing hook \"${hook}\""

			eval "${hook}"

			ret=$?

			if test ${ret} != 0; then
				log_err "${stage}/${substage}/${hook} exited with error code ${ret}"
				exit 1
			fi
		done
	done
done

# All done
if list_find ab_stages build; then
	log_info "Autobuild finished"
fi

exit 0
