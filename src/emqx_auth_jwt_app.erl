%%--------------------------------------------------------------------
%% Copyright (c) 2020 EMQ Technologies Co., Ltd. All Rights Reserved.
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

-module(emqx_auth_jwt_app).

-behaviour(application).

-behaviour(supervisor).

-emqx_plugin(auth).

-export([start/2, stop/1]).

-export([init/1]).

-define(APP, emqx_auth_jwt).

-define(JWT_ACTION, {emqx_auth_jwt, check, [auth_env()]}).

start(_Type, _Args) ->
    ok = emqx_auth_jwt:register_metrics(),
    emqx:hook('client.authenticate', ?JWT_ACTION),
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

stop(_State) ->
    emqx:unhook('client.authenticate', ?JWT_ACTION).

%%--------------------------------------------------------------------
%% Dummy supervisor
%%--------------------------------------------------------------------

init([]) ->
    Options = [{secret, env(secret, undefined)},
               {pubkey, env(pubkey, undefined)},
               {jwks_addr, env(jwks, undefined)}],
    Svr = #{id => jwt_svr,
            start => {emqx_auth_jwt_svr, start_link, [Options]},
            restart => permanent,
            shutdown => brutal_kill,
            type => worker,
            modules => [emqx_auth_jwt_svr]},
    {ok, {{one_for_all, 1, 10}, [Svr]}}.

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------

auth_env() ->
    #{ from => env(from, password)
     , checklists => env(verify_claims, [])
     }.

env(Key, Default) ->
    application:get_env(?APP, Key, Default).

