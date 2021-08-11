ID_OFFSET=$(or $(shell id -u docker 2>/dev/null),0)
UID=$(shell expr $$(id -u) - ${ID_OFFSET})
GID=$(shell expr $$(id -g) - ${ID_OFFSET})
USER=$(shell id -un)
GROUP=$(shell id -gn)
WORKSPACE=${CURDIR}
TERMINAL=$(shell test -t 0 && echo t)

.SUFFIXES:
MAKEFLAGS += --no-builtin-rules

all:
	@echo "$@ Not supported" 1>&2
	@false

USERSPEC=--user=${UID}:${GID}
image_name=${USER}_$(basename $(1))

%.image: Dockerfile-%
	docker build --tag $(call image_name,$@) ${DOCKER_BUILD_OPTS} -f $^\
	 --build-arg USERINFO=${USER}:${UID}:${GROUP}:${GID}:${KVM}\
	 $(if ${http_proxy},--build-arg http_proxy=${http_proxy})\
	 .

%.print:
	@echo $($(basename $@))

repo_init:
	./repo.sh init

%.repo_update:
	./repo.sh update $(basename $@)

%.image_run:
	docker run --rm --init --hostname $@ -i${TERMINAL} -w ${WORKSPACE} -v ${WORKSPACE}:${WORKSPACE}\
	 ${DOCKER_RUN_OPTS}\
	 ${USERSPEC} $(call image_name, $@) ${CMD}

%.image_print:
	@echo "$(call image_name, $@)"

CCACHE_CONFIG=--max-size=256M --set-config=compression=true

%.ccache-init:
	${MAKE} ${basename $@}.image_run CMD='env CCACHE_DIR=${WORKSPACE}/.ccache ccache ${CCACHE_CONFIG}'

CPU_CORES=$(shell getconf _NPROCESSORS_ONLN 2>/dev/null)

%.ccache-zero-stats:
	${MAKE} ${basename $@}.image_run CMD='env CCACHE_DIR=${WORKSPACE}/.ccache ccache ${CCACHE_CONFIG} --zero-stats'

%.ccache-show-stats:
	${MAKE} ${basename $@}.image_run CMD='env CCACHE_DIR=${WORKSPACE}/.ccache ccache ${CCACHE_CONFIG} --show-stats'

%.ccache:
	${MAKE} ${basename $@}.image_run CMD="env CCACHE_DIR=${WORKSPACE}/.ccache  ./build_qemu.sh $(basename $@) $(if ${CPU_CORES},-j${CPU_CORES})"

submodules:
	git -C qemu -c protocol.version=2 submodule update --jobs 2 --depth 1 --init ui/keycodemapdb tests/fp/berkeley-testfloat-3 tests/fp/berkeley-softfloat-3 meson dtc capstone slirp
	cd qemu && scripts/git-submodule.sh update ui/keycodemapdb tests/fp/berkeley-testfloat-3 tests/fp/berkeley-softfloat-3 meson dtc capstone slirp