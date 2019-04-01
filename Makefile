.PHONY: tests

PROJECT = emqx_auth_jwt
PROJECT_DESCRIPTION = EMQ X Authentication with JWT

NO_AUTOPATCH = cuttlefish

DEPS = jwerl clique

dep_jwerl  = git-emqx https://github.com/G-Corp/jwerl 1.0.0
dep_clique = git-emqx https://github.com/emqx/clique v0.3.11

CUR_BRANCH := $(shell git branch | grep -e "^*" | cut -d' ' -f 2)
BRANCH := $(if $(filter $(CUR_BRANCH), master develop), $(CUR_BRANCH), develop)

BUILD_DEPS = emqx cuttlefish
dep_emqx = git-emqx https://github.com/emqx/emqx $(BRANCH)
dep_cuttlefish = git-emqx https://github.com/emqx/cuttlefish v2.2.1

TEST_DEPS = emqx_ct_helper
dep_emqx_ct_helper = git-emqx https://github.com/emqx/emqx-ct-helpers $(BRANCH)

ERLC_OPTS += +debug_info

TEST_ERLC_OPTS += +debug_info

COVER = true

$(shell [ -f erlang.mk ] || curl -s -o erlang.mk https://raw.githubusercontent.com/emqx/erlmk/master/erlang.mk)
include erlang.mk

app.config::
	./deps/cuttlefish/cuttlefish -l info -e etc/ -c etc/emqx_auth_jwt.conf -i priv/emqx_auth_jwt.schema -d data
