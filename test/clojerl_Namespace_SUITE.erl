-module(clojerl_Namespace_SUITE).

-include("clojerl.hrl").
-include("clj_test_utils.hrl").

-export([ all/0
        , init_per_suite/1
        , end_per_suite/1
        , init_per_testcase/2
        , end_per_testcase/2
        ]).

-export([ hash/1
        , str/1
        , current/1
        , intern/1
        , alias/1
        , refer/1
        , import/1
        , find_or_create/1
        , complete_coverage/1
        ]).

-spec all() -> [atom()].
all() -> clj_test_utils:all(?MODULE, ['forty-two']).

-spec init_per_suite(config()) -> config().
init_per_suite(Config) -> clj_test_utils:init_per_suite(Config).

-spec end_per_suite(config()) -> config().
end_per_suite(Config) -> Config.

-spec init_per_testcase(atom(), config()) -> config().
init_per_testcase(_, Config) ->
  Config.

-spec end_per_testcase(atom(), config()) -> config().
end_per_testcase(_, Config) ->
  Nss   = 'clojerl.Namespace':all(),
  Names = ['clojerl.Namespace':name(Ns) || Ns <- Nss],
  ['clojerl.Namespace':remove(N) || N <- Names],
  Config.

%%------------------------------------------------------------------------------
%% Test Cases
%%------------------------------------------------------------------------------

-spec hash(config()) -> result().
hash(_Config) ->
  NsName1 = <<"foo">>,
  NsSym1  = clj_rt:symbol(NsName1),
  NsName2 = <<"bar">>,
  NsSym2  = clj_rt:symbol(NsName2),

  Ns1 = 'clojerl.Namespace':find_or_create(NsSym1),
  Ns2 = 'clojerl.Namespace':find_or_create(NsSym2),

  Hash1 = clj_rt:hash(Ns1),
  Hash2 = clj_rt:hash(Ns2),
  false = Hash1 =:= Hash2,

  Hash2 = clj_rt:hash(Ns2),

  {comment, ""}.

-spec str(config()) -> result().
str(_Config) ->
  NsName1 = <<"foo">>,
  NsSym1  = clj_rt:symbol(NsName1),
  Ns1 = 'clojerl.Namespace':find_or_create(NsSym1),

  <<"foo">> = clj_rt:str(Ns1),

  {comment, ""}.

-spec current(config()) -> result().
current(_Config) ->
  Current0 = 'clojerl.Namespace':current(),

  NsName   = <<"foo">>,
  NsSym    = clj_rt:symbol(NsName),
  Ns       = 'clojerl.Namespace':find_or_create(NsSym),

  Ns       = 'clojerl.Namespace':current(Ns),
  Ns       = 'clojerl.Namespace':current(),

  true     = Current0 =/= Ns,

  {comment, ""}.

-spec intern(config()) -> result().
intern(_Config) ->
  NsSym   = clj_rt:symbol(<<"foo">>),
  NameSym = clj_rt:symbol(<<"bar">>),
  Ns      = 'clojerl.Namespace':find_or_create(NsSym),
  Ns      = 'clojerl.Namespace':intern(Ns, NameSym),

  Var     = 'clojerl.Namespace':find_var(NameSym),
  true    = Var =/= ?NIL,

  ?NIL    = 'clojerl.Namespace':find_var(NsSym),

  FooBarSym = clj_rt:symbol(<<"foo">>, <<"bar">>),
  Var0      = 'clojerl.Namespace':find_var(FooBarSym),

  Var1      = clj_rt:with_meta(Var0, #{foo => bar}),
  Ns        = 'clojerl.Namespace':update_var(Var1),
  Var1      = 'clojerl.Namespace':find_var(FooBarSym),

  Mapping1  = 'clojerl.Namespace':get_mappings(Ns),
  1         = maps:size(Mapping1),

  FooBazSym = clj_rt:symbol(<<"foo">>, <<"baz">>),
  ?NIL      = 'clojerl.Namespace':find_var(FooBazSym),

  Ns      = 'clojerl.Namespace':unmap(Ns, NameSym),
  ?NIL    = 'clojerl.Namespace':find_var(NameSym),

  {comment, ""}.

-spec alias(config()) -> result().
alias(_Config) ->
  Ns1Sym  = clj_rt:symbol(<<"foo">>),
  Ns2Sym  = clj_rt:symbol(<<"baz">>),
  NameSym = clj_rt:symbol(<<"bar">>),
  Ns1     = 'clojerl.Namespace':find_or_create(Ns1Sym),
  Ns2     = 'clojerl.Namespace':find_or_create(Ns2Sym),

  Ns1      = 'clojerl.Namespace':add_alias(Ns1, NameSym, Ns2),
  Aliases1 = 'clojerl.Namespace':get_aliases(Ns1),
  1        = maps:size(Aliases1),

  Ns2      = 'clojerl.Namespace':alias(Ns1, NameSym),
  true     = Ns2 =/= ?NIL,
  ?NIL     = 'clojerl.Namespace':alias(Ns1, Ns1Sym),

  Ns1      = 'clojerl.Namespace':remove_alias(Ns1, NameSym),
  Aliases2 = 'clojerl.Namespace':get_aliases(Ns1),
  0        = maps:size(Aliases2),

  {comment, ""}.

-spec refer(config()) -> result().
refer(_Config) ->
  NsSym   = clj_rt:symbol(<<"foo">>),
  NameSym = clj_rt:symbol(<<"bar">>),
  Ns      = 'clojerl.Namespace':find_or_create(NsSym),
  Ns      = 'clojerl.Namespace':intern(Ns, NameSym),

  Var0    = 'clojerl.Namespace':find_var(NameSym),

  Var1    = clj_rt:with_meta(Var0, #{foo => bar}),
  Ns      = 'clojerl.Namespace':refer(Ns, NameSym, Var1),
  Var1    = 'clojerl.Namespace':find_var(NameSym),

  {comment, ""}.

-spec import(config()) -> result().
import(_Config) ->
  NsSym    = clj_rt:symbol(<<"foo">>),
  Ns       = 'clojerl.Namespace':find_or_create(NsSym),
  Ns       = 'clojerl.Namespace':import_type(<<"clojerl.String">>),

  Mapping1 = 'clojerl.Namespace':get_mappings(Ns),
  1        = maps:size(Mapping1),

  {comment, ""}.

-spec find_or_create(config()) -> result().
find_or_create(_Config) ->
  NsName = <<"clojerl_Namespace_SUITE">>,
  NsSym  = clj_rt:symbol(NsName),

  Ns     = 'clojerl.Namespace':find_or_create(NsSym),
  true   = Ns =/= ?NIL,
  NsSym  = 'clojerl.Namespace':name(Ns),

  ct:comment("There is only one ns"),
  [Ns]    = 'clojerl.Namespace':all(),

  ct:comment("Trying to find the same ns does not create a new one"),
  Ns      = 'clojerl.Namespace':find_or_create(NsSym),
  [Ns]    = 'clojerl.Namespace':all(),

  {comment, ""}.

-spec complete_coverage(config()) -> result().
complete_coverage(_Config) ->
  ProcessName = 'clojerl.Namespace',

  ct:comment("Force handle_info execution"),
  ProcessName ! ok,

  ct:comment("Force handle_cast execution"),
  gen_server:cast(ProcessName, ok),

  ct:comment("Call code_change"),
  ProcessName:code_change(ok, undefined, undefined),

  ct:comment("Call code_change"),
  ProcessName:terminate(ok, undefined),

  {comment, ""}.