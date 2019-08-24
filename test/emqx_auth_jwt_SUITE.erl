%%--------------------------------------------------------------------
%% Copyright (c) 2019 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_auth_jwt_SUITE).

-export([ all/0
        , groups/0
        , init_per_suite/1
        , end_per_suite/1
        ]).

-export([ t_check_auth/1
        , t_check_claims/1
        , t_check_claims_clientid/1
        , t_check_claims_username/1
        ]).

-include_lib("eunit/include/eunit.hrl").

-include_lib("common_test/include/ct.hrl").

-include_lib("emqx/include/emqx.hrl").

-define(APP, emqx_auth_jwt).

all() ->
    [{group, emqx_auth_jwt}].

groups() ->
    [{emqx_auth_jwt, [sequence], [ t_check_auth
                                 , t_check_claims
                                 , t_check_claims_clientid
                                 , t_check_claims_username
                                 ]}
    ].

init_per_suite(Config) ->
    emqx_ct_helpers:start_apps([emqx, emqx_auth_jwt], fun set_special_configs/1),
    Config.

end_per_suite(_Config) ->
    emqx_ct_helpers:stop_apps([emqx_auth_jwt, emqx]).

set_special_configs(emqx) ->
    application:set_env(emqx, allow_anonymous, false),
    application:set_env(emqx, acl_nomatch, deny),
    application:set_env(emqx, enable_acl_cache, false),
    LoadedPluginPath = filename:join(["test", "emqx_SUITE_data", "loaded_plugins"]),
    AclFilePath = filename:join(["test", "emqx_SUITE_data", "acl.conf"]),
    application:set_env(emqx, plugins_loaded_file,
                        emqx_ct_helpers:deps_path(emqx, LoadedPluginPath)),
    application:set_env(emqx, acl_file,
                        emqx_ct_helpers:deps_path(emqx, AclFilePath));

set_special_configs(emqx_auth_jwt) ->
    application:set_env(emqx_auth_jwt, secret, "emqxsecret"),
    application:set_env(emqx_auth_jwt, from, password);

set_special_configs(_) ->
    ok.

%%------------------------------------------------------------------------------
%% Testcases
%%------------------------------------------------------------------------------

t_check_auth(_) ->
    Plain = #{client_id => <<"client1">>, username => <<"plain">>},
    Jwt = jwerl:sign([{client_id, <<"client1">>},
                      {username, <<"plain">>},
                      {exp, os:system_time(seconds) + 3}], hs256, <<"emqxsecret">>),
    ct:pal("Jwt: ~p~n", [Jwt]),

    Result0 = emqx_access_control:authenticate(Plain#{password => Jwt}),
    ct:pal("Auth result: ~p~n", [Result0]),
    ?assertMatch({ok, #{auth_result := success, jwt_claims := #{client_id := <<"client1">>}}}, Result0),

    ct:sleep(3100),
    Result1 = emqx_access_control:authenticate(Plain#{password => Jwt}),
    ct:pal("Auth result after 1000ms: ~p~n", [Result1]),
    ?assertMatch({error, _}, Result1),

    Jwt_Error = jwerl:sign([{client_id, <<"client1">>},
                            {username, <<"plain">>}], hs256, <<"secret">>),
    ct:pal("invalid jwt: ~p~n", [Jwt_Error]),
    Result2 = emqx_access_control:authenticate(Plain#{password => Jwt_Error}),
    ct:pal("Auth result for the invalid jwt: ~p~n", [Result2]),
    ?assertEqual({error, invalid_signature}, Result2),
    ?assertMatch({error, _}, emqx_access_control:authenticate(Plain#{password => <<"asd">>})).

t_check_claims(_) ->
    application:set_env(emqx_auth_jwt, verify_claims, [{sub, <<"value">>}]),
    Plain = #{client_id => <<"client1">>, username => <<"plain">>},
    Jwt = jwerl:sign([{client_id, <<"client1">>},
                      {username, <<"plain">>},
                      {sub, value},
                      {exp, os:system_time(seconds) + 3}], hs256, <<"emqxsecret">>),
    Result0 = emqx_access_control:authenticate(Plain#{password => Jwt}),
    ct:pal("Auth result: ~p~n", [Result0]),
    ?assertMatch({ok, #{auth_result := success, jwt_claims := _}}, Result0),
    Jwt_Error = jwerl:sign([{client_id, <<"client1">>},
                            {username, <<"plain">>}], hs256, <<"secret">>),
    Result2 = emqx_access_control:authenticate(Plain#{password => Jwt_Error}),
    ct:pal("Auth result for the invalid jwt: ~p~n", [Result2]),
    ?assertEqual({error, invalid_signature}, Result2).

t_check_claims_clientid(_) ->
    application:set_env(emqx_auth_jwt, verify_claims, [{client_id, <<"%c">>}]),
    Plain = #{client_id => <<"client23">>, username => <<"plain">>},
    Jwt = jwerl:sign([{client_id, <<"client23">>},
                      {username, <<"plain">>},
                      {exp, os:system_time(seconds) + 3}], hs256, <<"emqxsecret">>),
    Result0 = emqx_access_control:authenticate(Plain#{password => Jwt}),
    ct:pal("Auth result: ~p~n", [Result0]),
    ?assertMatch({ok, #{auth_result := success, jwt_claims := _}}, Result0),
    Jwt_Error = jwerl:sign([{client_id, <<"client1">>},
                            {username, <<"plain">>}], hs256, <<"secret">>),
    Result2 = emqx_access_control:authenticate(Plain#{password => Jwt_Error}),
    ct:pal("Auth result for the invalid jwt: ~p~n", [Result2]),
    ?assertEqual({error, invalid_signature}, Result2).

t_check_claims_username(_) ->
    application:set_env(emqx_auth_jwt, verify_claims, [{username, <<"%u">>}]),
    Plain = #{client_id => <<"client23">>, username => <<"plain">>},
    Jwt = jwerl:sign([{client_id, <<"client23">>},
                      {username, <<"plain">>},
                      {exp, os:system_time(seconds) + 3}], hs256, <<"emqxsecret">>),
    Result0 = emqx_access_control:authenticate(Plain#{password => Jwt}),
    ct:pal("Auth result: ~p~n", [Result0]),
    ?assertMatch({ok, #{auth_result := success, jwt_claims := _}}, Result0),
    Jwt_Error = jwerl:sign([{client_id, <<"client1">>},
                            {username, <<"plain">>}], hs256, <<"secret">>),
    Result3 = emqx_access_control:authenticate(Plain#{password => Jwt_Error}),
    ct:pal("Auth result for the invalid jwt: ~p~n", [Result3]),
    ?assertEqual({error, invalid_signature}, Result3).

