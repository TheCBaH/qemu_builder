#!/bin/sh
set -x
set -eu
cmd=$1;shift

repo=qemu
modules="ui/keycodemapdb tests/fp/berkeley-testfloat-3 tests/fp/berkeley-softfloat-3 meson dtc capstone slirp"
_git="git -C $repo.git"
case "$cmd" in
init)
    if [ ! -d $repo.git ]; then
        mkdir -p $repo.git
        $_git init .
        $_git remote add origin -t master https://github.com/qemu/qemu.git
    fi
    for b in master stable-5.0; do
        $_git remote set-branches --add origin $b
    done
    $_git commit -m empty --allow-empty
    $_git branch -M empty
    $_git config user.email "you@example.com"
    $_git config user.name "Your Name"
    $_git -c protocol.version=2 fetch --no-tags --depth 1 origin
    tree=$repo.git/.tree
    mkdir $tree
    git_dir=$(readlink -f $repo.git/.git)
    (
        cd $tree
        git --git-dir $git_dir --work-tree . checkout origin/master
        git --git-dir $git_dir --work-tree . submodule update --jobs 2 --depth 1 --init $modules
        git --git-dir $git_dir --work-tree . checkout empty
    )
    rm -rf $tree
    ;;
update)
    ref=$1;shift
    $_git -c protocol.version=2 fetch --no-tags --depth 1 origin
    _git="git -C $repo"
    if [ -d $repo ]; then
        $_git checkout .
        $_git clean -xdf
    else
        cp -rl $repo.git $repo
    fi
    $_git -c protocol.version=2 fetch --no-tags --depth 1 origin $ref
    $_git reset --merge FETCH_HEAD
	$_git -c protocol.version=2 submodule update --jobs 2 --depth 1 --init $modules
	(cd qemu ; scripts/git-submodule.sh update $modules)
    ;;
esac
