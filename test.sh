#!/usr/bin/env bash

mkdir -p ebin
rebar3 as test compile

erlc -Wall +debug_info -pa "$(pwd)/_build/test/lib/erlandono/ebin" -o ebin src/cut.erl
erlc -Wall +debug_info -pa "$(pwd)/_build/test/lib/erlandono/ebin" -o ebin src/do.erl
erlc -Wall +debug_info -pa "$(pwd)/_build/test/lib/erlandono/ebin" -o ebin src/import_as.erl

erlc -Wall +debug_info -pa "$(pwd)/_build/test/lib/erlandono/ebin" -pa ./ebin -o ebin ./src/test.erl
erlc -Wall +debug_info -pa "$(pwd)/_build/test/lib/erlandono/ebin" -pa ./ebin -o ebin ./test/erlandono_test.erl
