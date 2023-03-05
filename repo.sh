#!/bin/sh
set -x
set -eu
cmd=$1;shift

repo=qemu
modules="ui/keycodemapdb tests/fp/berkeley-testfloat-3 tests/fp/berkeley-softfloat-3 dtc"
_git="git -C $repo.git"
check_submodule () {
    if $_git submodule | grep $1; then
        modules="$modules $1"
    fi
}

check_submodules () {
    for m in meson capstone slirp ; do
        check_submodule $m
    done
}

case "$cmd" in
init)
    ref=${1:-master}
    if [ ! -d $repo.git ]; then
        mkdir -p $repo.git
        $_git init .
        $_git remote add origin -t master https://github.com/qemu/qemu.git
    fi
    for b in master stable-6.1 stable-6.0 stable-5.0 stable-4.0 stable-3.0; do
        $_git remote set-branches --add origin $b
    done
    if $_git rev-parse empty; then
        true
    else
        $_git config user.email "you@example.com"
        $_git config user.name "Your Name"
        $_git commit -m empty --allow-empty
        $_git branch -M empty
    fi
    $_git -c protocol.version=2 fetch --no-tags --depth 1 origin
    if [ $ref != master ]; then
        $_git -c protocol.version=2 fetch --no-tags --depth 1 origin $ref
        $_git update-ref refs/remotes/origin/$ref FETCH_HEAD~0
    fi
    tree=$repo.git/.tree
    rm -rf $tree;mkdir $tree
    git_dir=$(readlink -f $repo.git/.git)
    (
        cd $tree
        _git="git --git-dir $git_dir --work-tree ."
        $_git checkout origin/$ref
        $_git submodule sync
        check_submodules
        $_git submodule update --jobs 2 --depth 1 --init $modules
        $_git checkout empty
    )
    rm -rf $tree
    ;;
update)
    ref=$1;shift
    _git="git -C $repo"
    if [ -d $repo ]; then
        $_git checkout .
        $_git clean -xdf
    else
        cp -rl $repo.git $repo
    fi
    $_git -c protocol.version=2 fetch --no-tags --depth 1 origin $ref
    $_git reset --hard FETCH_HEAD
    $_git clean -xdf
    check_submodules
	$_git -c protocol.version=2 submodule update --jobs 2 --depth 1 --init $modules
    $_git submodule foreach git clean -xdf
	(cd qemu ; scripts/git-submodule.sh update $modules)
    ;;
esac
