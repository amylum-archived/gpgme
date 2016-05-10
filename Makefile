PACKAGE = gpgme
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=/usr --infodir=/tmp/trash
CONF_FLAGS = --enable-maintainer-mode
CFLAGS =

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/gpgme-//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

LIBGPG-ERROR_VERSION = 1.22-4
LIBGPG-ERROR_URL = https://github.com/amylum/libgpg-error/releases/download/$(LIBGPG-ERROR_VERSION)/libgpg-error.tar.gz
LIBGPG-ERROR_TAR = /tmp/libgpgerror.tar.gz
LIBGPG-ERROR_DIR = /tmp/libgpg-error
LIBGPG-ERROR_PATH = -I$(LIBGPG-ERROR_DIR)/usr/include -L$(LIBGPG-ERROR_DIR)/usr/lib

LIBASSUAN_VERSION = 2.4.2-4
LIBASSUAN_URL = https://github.com/amylum/libassuan/releases/download/$(LIBASSUAN_VERSION)/libassuan.tar.gz
LIBASSUAN_TAR = /tmp/libassuan.tar.gz
LIBASSUAN_DIR = /tmp/libassuan
LIBASSUAN_PATH = -I$(LIBASSUAN_DIR)/usr/include -L$(LIBASSUAN_DIR)/usr/lib

.PHONY : default submodule deps manual container deps build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(LIBGPG-ERROR_DIR) $(LIBGPG-ERROR_TAR)
	mkdir $(LIBGPG-ERROR_DIR)
	curl -sLo $(LIBGPG-ERROR_TAR) $(LIBGPG-ERROR_URL)
	tar -x -C $(LIBGPG-ERROR_DIR) -f $(LIBGPG-ERROR_TAR)
	rm -rf $(LIBASSUAN_DIR) $(LIBASSUAN_TAR)
	mkdir $(LIBASSUAN_DIR)
	curl -sLo $(LIBASSUAN_TAR) $(LIBASSUAN_URL)
	tar -x -C $(LIBASSUAN_DIR) -f $(LIBASSUAN_TAR)
	find /tmp -name '*.la' -delete

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	cd $(BUILD_DIR) && ./autogen.sh
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS) $(LIBGPG-ERROR_PATH) $(LIBASSUAN_PATH)' ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
	rm -rf $(RELEASE_DIR)/tmp
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYING.LESSER $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

