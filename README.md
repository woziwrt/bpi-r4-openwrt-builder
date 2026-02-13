# OpenWrt build for Banana Pi BPI-R4 (kernel 6.6)

This repository contains a script and a GitHub Actions workflow to build OpenWrt 24.10 for Banana Pi BPI‑R4 (MT7988, Wi‑Fi 7) using the MediaTek SDK.

Goal: you do not need a local build machine. You can trigger the build on GitHub and download ready-to-use images. Advanced users can tweak the config if they want.

Use the latest workflow for normal builds, and the commit workflow only if you know you need a specific commit/branch/tag.

## Important note for forks

If you create a **fork** of this repository, GitHub Actions will not run automatically.

To make the build workflows work in your fork, you must:

1. Go to the **Actions** tab in *your forked repository* and click the button to **enable workflows** for this repo.
2. In your fork, open **Settings → Actions → General** and check:
   - **Actions permissions**: allow GitHub Actions to run for this repository.
   - **Workflow permissions**: set `GITHUB_TOKEN` to **Read and write permissions**, otherwise the workflows cannot create releases, tags, or upload artifacts.

---

## 1. Quick start - ready-made image  (workflow "latest")

If you only want a prebuilt firmware for BPI‑R4 and do not care about specific commit, use the "latest"workflow.

It always builds from the current state of the repository (latest commit on the main branch).

Steps:

1. Open the “Actions” tab in this repository.
2. Select the workflow “Build OpenWrt (BPI-R4, kernel 6.6, latest)”.
3. Click “Run workflow” and confirm. You do not need to change anything

After the workflow finishes :

1. Open the “Releases” tab.
2. Download the latest release (tag bpi-r4-latest).

Important files in the release:

- ``openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb`` – sysupgrade from an existing OpenWrt.
- ``openwrt-mediatek-filogic-bananapi_bpi-r4-sdcard.img.gz`` – SD card image.
- ``sha256sums`` – checksums for verification.
  
The release is always updated under the same tag  bpi-r4-latest , so the “Created” date on GitHub does not change. Check the list of files and the “Updated” time to see the latest build.

You do not need to change anything in the repository for this use case.

---
## 2.	Build from a specific commit/branch (workflow “commit”)

If you want to build firmware from a specific commit, branch or tag, use the “commit” workflow.
This is useful if you want to reproduce an older build or test a feature branch.

Steps:

1.	Open the “Actions” tab in this repository.
2.	Select the workflow “Build OpenWrt (BPI-R4, 6.6, commit)”.
3.	Click “Run workflow”
	
In the dialog:

1.	In the “Git reference” field enter what you want to build:
 •	a commit SHA (for example 1234abcd…), or
 •	a branch name (for example main, feature-x), or
 •	a tag name (for example v1.0).

2.	Confirm to start the workflow.
  
After the workflow finishes:

1.	Open the “Releases” tab.
2.	Download the latest release (tag bpi-r4-latest), same as in section 1. The release content reflects the commit/branch/tag you selected when starting the workflow.
	
Note: if you are not sure what to use, stick to the “latest” workflow from section 1.

## 3. Add/remove a few packages (GitHub only)

You can slightly customize the firmware by editing the final config file directly on GitHub.
The build still runs on GitHub’s servers, not on your machine.

Step 1 – Open the config file

1. In this repository, open the directory “my_files”.
2. Click on the file “my_final_defconfig”.

Step 2 – Edit the config on GitHub

1. Click the pencil icon (“Edit this file”).
2. In the file you will see lines like:
  
   ``CONFIG_PACKAGE_iperf3=y``  
   ``CONFIG_PACKAGE_htop is not set``
  
   Meaning:
   
   - ``CONFIG_PACKAGE_xyz=y`` → package enabled.
   - ``CONFIG_PACKAGE_xyz is not set`` → package disabled.

4. To enable a package, change:

   ``CONFIG_PACKAGE_htop is not set``

   to:

   ``CONFIG_PACKAGE_htop=y``

5. To disable a package, change:

   ``CONFIG_PACKAGE_iperf3=y``

   to:

   ``CONFIG_PACKAGE_iperf3 is not set``

6. Important: only change lines starting with “CONFIG_PACKAGE_”.
   Do not touch kernel / target / MTK SDK options unless you really know what you are doing.

7. At the bottom of the page click “Commit changes” to save the file.

Step 3 – Trigger a new build

1. Go to the “Actions” tab.
2. Run either workflow:
   
   •	“Build OpenWrt (BPI-R4, 6.6, latest)” – build from the latest commit.
 
   •	“Build OpenWrt (BPI-R4, 6.6, commit)” – build from a specific commit/branch/tag.

About dependencies

The build script copies “my_final_defconfig” to “.config” and then runs:

   ``make defconfig``

The OpenWrt build system automatically fills in missing options and dependencies.
If you only toggle a few CONFIG_PACKAGE_… options, the build should stay consistent.

---

## 4. Local build (optional, advanced)

If you prefer to build locally on Linux:

Requirements (example: Ubuntu 22.04)

- around 120 GB free disk space.
- basic build tools and libraries:
   ```
   sudo apt-get update  
   sudo apt-get install -y \
     build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
     gettext libncurses-dev libssl-dev python3-distutils python3-setuptools \
     rsync swig unzip zlib1g-dev file wget libelf-dev ccache git
   ```
Clone and build
   ```
   git clone https://github.com/woziwrt/bpi-r4-openwrt-builder.git  
   cd bpi-r4-openwrt-builder  
   chmod +x ./bpi-r4-openwrt-builder.sh  
   ./bpi-r4-openwrt-builder.sh  
   ```
After the script finishes, images are in:

   ``openwrt/bin/targets/mediatek/filogic/``

---

## 5. Repository contents

- ``bpi-r4-openwrt-builder.sh`` – main build script (clone OpenWrt + MTK, prepare, build, apply config).
- ``my_files/`` – custom config (my_final_defconfig), patches, custom packages and LuCI apps.
- ``.github/workflows/`` – GitHub Actions workflow:
  - frees disk space,
  - runs the build script,
  - cleans build output,
  - uploads artifacts,
  - creates a release with only the relevant BPI‑R4 files,
  - keeps only the latest release.

---

## 6. Notes

- This build is for Banana Pi BPI‑R4 only.
- For simple custom builds, change only CONFIG_PACKAGE_… lines in my_final_defconfig.
- OpenWrt and MTK SDK commits are pinned; updating them requires manual work.

### Notes about GitHub runners and mirrors

This workflow runs on GitHub-hosted runners, where the amount of free disk space is not guaranteed.
Sometimes the runner only provides enough space for a minimal image, but not for a full release with many additional packages.

If a build fails with “no space left on device” or similar disk-related errors, it usually means the assigned runner did not have enough free disk space.
In that case, simply re-run the workflow later; when the runner happens to have around 100 GB of free space available, the full build including many packages is much more likely to succeed.

In addition, the build system downloads sources and package feeds from external mirrors.
If some of these mirrors are temporarily unavailable or slow, the workflow can also fail or take much longer to finish.
Re-running the workflow later often resolves such transient mirror issues.

