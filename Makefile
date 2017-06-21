######################################################################
# Thanks:
#   https://github.com/aktau/github-release
#   https://github.com/boertel/bump
#   https://github.com/MozillaSecurity/dolly
#   https://gist.github.com/danielestevez/2044589
#   https://github.com/vaab/gitchangelog
#   https://github.com/tj/git-extras (not implemented yet because not
#       know to generate release changfelog like github-release)
######################################################################

# Sane checks
ifeq ($(GITHUB_TOKEN),)
  $(error GITHUB_TOKEN is not set)
endif

######################################################################
# Constants
######################################################################

LAST_TAG := $(shell git describe --abbrev=0 --tags)
COMPARISON := "$(LAST_TAG)..HEAD"

CUR_VER=$(shell git describe --abbrev=0 --tags)
CUR_TAG=$(shell git describe --abbrev=0 --tags)
NUM_TAGS=$(shell git tag | wc -l)
IS_GITDIR=$(shell git rev-parse --is-inside-work-tree)
NEXT_PATCH=$(shell tools/bump patch `git describe --tags --abbrev=0`)
NEXT_MINOR=$(shell tools/bump minor `git describe --tags --abbrev=0`)
NEXT_MAJOR=$(shell tools/bump major `git describe --tags --abbrev=0`)

.PHONY: clean-pyc clean-build clean guard-%

help:
	@echo "docker-up-prod        - Run docker-compose -f docker-compose-dev.yml up -d."
	@echo "docker-down-prod      - Run docker-compose -f docker-compose-dev.yml down."
	@echo "docker-build-prod     - build Docker dev image."
	@echo "docker-clean-prod     - clean Docker dev image."
	@echo "docker-up-dev         - Run docker-compose -f docker-compose-dev.yml up -d."
	@echo "docker-down-dev       - Run docker-compose -f docker-compose-dev.yml down."
	@echo "docker-build-dev      - build Docker dev image."
	@echo "docker-clean-dev      - clean Docker dev image."
	@echo "docker-clean-dangling - clean all Docker dangling images."
	@echo "check-status          - will check whether there are outstanding changes."
	@echo "check-release         - will check whether the current directory matches the tagged release in git."
	@echo "patch-release         - increments the patch release level, build and push to github."
	@echo "minor-release         - increments the minor release level, build and push to github."
	@echo "major-release         - increments the major release level, build and push to github."
	@echo "clean                 - remove all build artifacts"
	@echo "clean-build           - remove build artifacts"
	@echo "clean-pyc             - remove Python file artifacts"
	@echo "showver               - will show the current release tag based on the directory content."
	@echo "rootfs-fixperms       - Fix permissions in rootfs dir"
	@echo "install-tools         - install tools needed to manage the project"

rootfs-fixperms:
	-@chmod -R go-w rootfs
	-@chmod -R ugo+x rootfs/opt/daspanel/bin
	-@chmod -R ugo+x rootfs/opt/daspanel/sbin
	-@chmod -R ugo+x rootfs/opt/daspanel/bootstrap

docker-down-prod:
	docker-compose -f docker-compose.yml down

docker-up-prod:
	docker-compose -f docker-compose.yml up -d

docker-clean-prod:
	-@docker rmi daspanel/engine-php71

docker-build-prod: clean docker-clean-prod rootfs-fixperms
	docker build -f Dockerfile -t daspanel/engine-php71 .


docker-down-dev:
	docker-compose -f docker-compose-dev.yml down

docker-up-dev:
	docker-compose -f docker-compose-dev.yml up -d

docker-clean-dangling:
	docker ps -a -f status=exited -q  | xargs -r docker rm -v
	docker images --no-trunc -q -f dangling=true | xargs -r docker rmi

docker-clean-dev:
	-@docker rmi daspanel/engine-php71-dev

docker-build-dev: clean docker-clean-dev rootfs-fixperms
	docker build -f Dockerfile.dev -t daspanel/engine-php71-dev .

install-tools:
	sudo pip install gitchangelog pystache
	wget https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2 -O github-release.tar.bz2
	tar xvjf github-release.tar.bz2 --strip-components 3 -C tools/
	rm github-release.tar.bz2
	chmod ugo+x tools/github-release
	wget https://raw.githubusercontent.com/boertel/bump/master/bump -O tools/bump
	chmod ugo+x tools/bump

# Verify if env variable passe as argument is defined
guard-%: GUARD
	@ if [ -z '${${*}}' ]; then echo 'Environment variable $* not set.' && exit 1; fi

.PHONY: GUARD
GUARD:

patch-release: guard-GITHUB_TOKEN check-status check-release
	echo "Patch release $(NEXT_PATCH)..."
	@git tag -a "$(NEXT_PATCH)" -m "Patch release $(NEXT_PATCH)"
	@gitchangelog > ./CHANGELOG.md
	@git tag -d "$(NEXT_PATCH)"
	@git add CHANGELOG.md
	@git commit -am "CHANGELOG.md for $(NEXT_PATCH) generated !cosmetic"
	@git tag -a "$(NEXT_PATCH)" -m "Patch release $(NEXT_PATCH)"
	@git push
	@git push --tags
	@changelog=$$(git log $(COMPARISON) --oneline --no-merges) ; \
	echo "**Changelog $(NEXT_PATCH)**<br/>$$changelog"; \
	tools/github-release release -u admindaspanel -r engine-php71 -t $(NEXT_PATCH) -n $(NEXT_PATCH) -d "**Changelog**<br/>$$changelog"

minor-release: guard-GITHUB_TOKEN check-status check-release
	echo "Minor release $(NEXT_MINOR)..."
	@git tag -a "$(NEXT_MINOR)" -m "Minor release $(NEXT_MINOR)"
	@gitchangelog > ./CHANGELOG.md
	@git tag -d "$(NEXT_MINOR)"
	@git add CHANGELOG.md
	@git commit -am "CHANGELOG.md for $(NEXT_MINOR) generated !cosmetic"
	@git tag -a "$(NEXT_MINOR)" -m "Minor release $(NEXT_MINOR)"
	@git push
	@git push --tags
	echo $(COMPARISON)
	@changelog=$$(git log $(COMPARISON) --oneline --no-merges) ; \
	echo "**Changelog $(NEXT_MINOR)**<br/>$$changelog"; \
	tools/github-release release -u admindaspanel -r engine-php71 -t $(NEXT_MINOR) -n $(NEXT_MINOR) -d "**Changelog**<br/>$$changelog"

major-release: guard-GITHUB_TOKEN check-status check-release
	echo "Major release $(NEXT_MAJOR)..."
	@git tag -a "$(NEXT_MAJOR)" -m "Major release $(NEXT_MAJOR)"
	@gitchangelog > ./CHANGELOG.md
	@git tag -d "$(NEXT_MAJOR)"
	@git add CHANGELOG.md
	@git commit -am "CHANGELOG.md for $(NEXT_MAJOR) generated !cosmetic"
	@git tag -a "$(NEXT_MAJOR)" -m "Major release $(NEXT_MAJOR)"
	@git push
	@git push --tags
	@changelog=$$(git log $(COMPARISON) --oneline --no-merges) ; \
	echo "**Changelog $(NEXT_MAJOR)**<br/>$$changelog"; \
	tools/github-release release -u admindaspanel -r engine-php71 -t $(NEXT_MAJOR) -n $(NEXT_MAJOR) -d "**Changelog**<br/>$$changelog"


showver:
	@echo $(CUR_TAG)

check-status:
	@if [ `git status -s . | wc -l` != 0 ] ; then echo "\n\n\n\n\tERROR: YOU HAVE UNCOMMITTED CHANGES\n\n  Commit any pending changes before push new release.\n\n\n\n"; exit 1; fi

check-release:
	@echo "LAST_TAG=$(LAST_TAG), Current TAG $(CUR_TAG), RELEASE $(CUR_VER) - $(NUM_TAGS) - $(IS_GITDIR)"
	@if [ $(IS_GITDIR) != true ] ; then echo "\n\n\n\n\tERROR: YOU DON'T HAVE CREATED A GIT PROJECT\n\n  Create and initialize a git project before continue.\n\n\n\n"; exit 1; fi
	@if [ $(NUM_TAGS) = 0 ] ; then echo "\n\n\n\n\tERROR: YOU NOT HAVE CREATED ANY GIT TAG\n\n  Commit any pending changes and create new tag/release using:\n\n\t'make [minor,major,patch]-release'.\n\n\n\n"; exit 1; fi
	@echo "*** OK to push release ***"

clean: clean-build clean-pyc
	find . -name '*~' -exec rm -f {} +

clean-build:
	rm -rf build/
	rm -rf dist/
	rm -rf .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -f {} +

clean-pyc:
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +
	find . -name '*~' -exec rm -f {} +



