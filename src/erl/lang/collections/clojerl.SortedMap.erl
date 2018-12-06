-module('clojerl.SortedMap').

-compile({no_auto_import, [{apply, 2}]}).

-include("clojerl.hrl").

-behavior('clojerl.IAssociative').
-behavior('clojerl.ICounted').
-behavior('clojerl.IColl').
-behavior('clojerl.IEquiv').
-behavior('clojerl.IFn').
-behavior('clojerl.IHash').
-behavior('clojerl.ILookup').
-behavior('clojerl.IMap').
-behavior('clojerl.IMeta').
-behavior('clojerl.ISeqable').
-behavior('clojerl.ISorted').
-behavior('clojerl.IStringable').

-export([ ?CONSTRUCTOR/1
        , ?CONSTRUCTOR/2
        ]).
-export([ contains_key/2
        , entry_at/2
        , assoc/3
        ]).
-export([count/1]).
-export([ cons/2
        , empty/1
        ]).
-export([equiv/2]).
-export([apply/2]).
-export([hash/1]).
-export([ get/2
        , get/3
        ]).
-export([ keys/1
        , vals/1
        , without/2
        ]).
-export([ meta/1
        , with_meta/2
        ]).
-export([ seq/1
        , to_list/1
        ]).
-export(['_'/1]).
-export([str/1]).

-import( clj_hash_collision
       , [ get_entry/3
         , create_entry/4
         , without_entry/3
         ]
       ).

-type mappings() :: #{integer() => {any(), true} | [{any(), true}]}.

-type type() :: #{ ?TYPE => ?M
                 , keys  => mappings()
                 , vals  => any()
                 , count => non_neg_integer()
                 , meta  => ?NIL | any()
                 }.

-spec ?CONSTRUCTOR([any()]) -> type().
?CONSTRUCTOR(KeyValues) when is_list(KeyValues) ->
  KeyValuePairs = build_key_values([], KeyValues),
  {Count, Keys}   = lists:foldl(fun build_mappings/2, {0, #{}}, KeyValuePairs),
  Values = rbdict:from_list(KeyValuePairs),
  #{ ?TYPE => ?M
   , keys  => Keys
   , vals  => Values
   , count => Count
   , meta  => ?NIL
   }.

-spec ?CONSTRUCTOR(function(), [any()]) -> type().
?CONSTRUCTOR(Compare, KeyValues) when is_list(KeyValues) ->
  KeyValuePairs = build_key_values([], KeyValues),
  {Count, Keys} = lists:foldl(fun build_mappings/2, {0, #{}}, KeyValuePairs),
  Values = rbdict:from_list(Compare, KeyValuePairs),
  #{ ?TYPE => ?M
   , keys  => Keys
   , vals  => Values
   , count => Count
   , meta  => ?NIL
   }.

%% @private
-spec build_key_values(list(), list()) -> [{any(), any()}].
build_key_values(KeyValues, []) ->
  lists:reverse(KeyValues);
build_key_values(KeyValues, [K, V | Items]) ->
  build_key_values([{K, V} | KeyValues], Items).

%% @private
-spec build_mappings(any(), {integer(), mappings()}) -> {integer(), mappings()}.
build_mappings({K, _}, {Count, Map}) ->
  Hash = clj_rt:hash(K),
  {Diff, Entry} = create_entry(Map, Hash, K, true),
  {Count + Diff, Map#{Hash => Entry}}.

%%------------------------------------------------------------------------------
%% Protocols
%%------------------------------------------------------------------------------

%% clojerl.IAssociative

contains_key(#{?TYPE := ?M, keys := Keys}, Key) ->
  Hash = clj_rt:hash(Key),
  maps:is_key(Hash, Keys).

entry_at(#{?TYPE := ?M, keys := Keys, vals := Vals}, Key) ->
  Hash = clj_rt:hash(Key),
  case get_entry(Keys, Hash, Key) of
    {FoundKey, true} ->
      Val = rbdict:fetch(FoundKey, Vals),
      clj_rt:vector([FoundKey, Val]);
    ?NIL -> ?NIL
  end.

assoc( #{?TYPE := ?M, keys := Keys, vals := Vals0, count := Count} = M
     , Key0
     , Value
     ) ->
  Hash  = clj_rt:hash(Key0),
  {Diff, Entry} = create_entry(Keys, Hash, Key0, true),
  {Key1, Vals1} = case get_entry(Keys, Hash, Key0) of
                    ?NIL      -> {Key0, Vals0};
                    {K, true} -> {K, rbdict:erase(K, Vals0)}
                  end,
  M#{ keys  => Keys#{Hash => Entry}
    , vals  => rbdict:store(Key1, Value, Vals1)
    , count => Count + Diff
    }.

%% clojerl.ICounted

count(#{?TYPE := ?M, count := Count}) -> Count.

%% clojerl.IEquiv

equiv( #{?TYPE := ?M, vals := ValsX, count := Count}
     , #{?TYPE := ?M, vals := ValsY, count := Count}
     ) ->
  Fun = fun({KeyX, ValueX}) ->
            ValueY = rbdict:fetch(KeyX, ValsY),
            ValueY /= ?NIL andalso clj_rt:equiv(ValueX, ValueY)
        end,
  lists:all(Fun, rbdict:to_list(ValsX));
equiv(#{?TYPE := ?M, keys := Keys, vals := Vals}, Y) ->
  case clj_rt:'map?'(Y) of
    true  ->
      TypeModule   = clj_rt:type_module(Y),
      KeyHashFun   = fun(X) -> {X, clj_rt:hash(X)} end,
      KeyHashPairs = lists:map( KeyHashFun
                              , 'erlang.List':to_list(TypeModule:keys(Y))
                              ),
      Fun = fun({Key, Hash}) ->
                Entry = get_entry(Keys, Hash, Key),
                Entry /= ?NIL andalso
                  clj_rt:equiv(rbdict:fetch(Key, Vals), TypeModule:get(Y, Key))
            end,
      maps:size(Keys) =:= TypeModule:count(Y)
        andalso lists:all(Fun, KeyHashPairs);
    false -> false
  end.

%% clojerl.IFn

apply(#{?TYPE := ?M} = M, [Key]) ->
  apply(M, [Key, ?NIL]);
apply(#{?TYPE := ?M} = M, [Key, NotFound]) ->
  get(M, Key, NotFound);
apply(_, Args) ->
  CountBin = integer_to_binary(length(Args)),
  error(<<"Wrong number of args for map, got: ", CountBin/binary>>).

%% clojerl.IColl

cons(#{?TYPE := ?M} = Map, ?NIL) ->
  Map;
cons(#{?TYPE := ?M} = M, X) ->
  IsVector = clj_rt:'vector?'(X),
  IsMap    = clj_rt:'map?'(X),
  case clj_rt:to_list(X) of
    [K, V] when IsVector ->
      assoc(M, K, V);
    KVs when IsMap ->
      Fun = fun(KV, Acc) ->
                [K, V] = clj_rt:to_list(KV),
                assoc(Acc, K, V)
            end,
      lists:foldl(Fun, M, KVs);
    _ ->
      error(<<"Can't conj something that is not a key/value pair or "
              "another map to a map.">>)
  end.

empty(#{?TYPE := ?M, vals := Vals}) ->
  Compare = rbdict:compare_fun(Vals),
  ?CONSTRUCTOR(Compare, []).

%% clojerl.IHash

hash(#{?TYPE := ?M, vals := Vals}) ->
  clj_murmur3:unordered(rbdict:to_list(Vals)).

%% clojerl.ILookup

get(#{?TYPE := ?M} = Map, Key) ->
  get(Map, Key, ?NIL).

get(#{?TYPE := ?M, keys := Keys, vals := Vals}, Key, NotFound) ->
  Hash = clj_rt:hash(Key),
  case get_entry(Keys, Hash, Key) of
    ?NIL   -> NotFound;
    {K, _} -> rbdict:fetch(K, Vals)
  end.

%% clojerl.IMap

keys(#{?TYPE := ?M, vals := Vals}) ->
  rbdict:fetch_keys(Vals).

vals(#{?TYPE := ?M, vals := Vals}) ->
  [V || {_, V} <- rbdict:to_list(Vals)].

without( #{?TYPE := ?M, keys := Keys0, vals := Vals0, count := Count} = M
       , Key
       ) ->
  Hash  = clj_rt:hash(Key),
  {Diff, Keys1} = without_entry(Keys0, Hash, Key),
  Vals1 = case get_entry(Keys0, Hash, Key) of
            ?NIL -> Vals0;
            {K, true} -> rbdict:erase(K, Vals0)
         end,
  M#{ keys  => Keys1
    , vals  => Vals1
    , count => Count + Diff
    }.

%% clojerl.IMeta

meta(#{?TYPE := ?M, meta := Meta}) -> Meta.

with_meta(#{?TYPE := ?M} = Map, Metadata) ->
  Map#{meta => Metadata}.

%% clojerl.ISeqable

seq(#{?TYPE := ?M} = Map) ->
  case to_list(Map) of
    [] -> ?NIL;
    X -> X
  end.

to_list(#{?TYPE := ?M, vals := Vals}) ->
  VectorFun = fun({Key, Val}) ->
                  clj_rt:vector([Key, Val])
              end,
  lists:map(VectorFun, rbdict:to_list(Vals)).

%% clojerl.ISorted

'_'(_) -> ?NIL.

%% clojerl.IStringable

str(#{?TYPE := ?M} = SortedMap) ->
  clj_rt:print(SortedMap).
