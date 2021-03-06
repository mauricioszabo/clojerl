-module(clj_scope).

-include("clojerl.hrl").

-export([ new/0
        , new/1
        , parent/1
        , get/2
        , get/3
        , contains/2
        , put/2
        , put/3
        , update/3
        , to_map/2
        , values/1
        ]).

-type scope() :: #{ parent   => scope() | ?NIL
                  , mappings => map()
                  }.

-spec new() -> scope().
new() -> new(?NIL).

-spec new(scope() | ?NIL) -> scope().
new(Parent) ->
 #{ parent   => Parent
  , mappings => #{}
  }.

-spec parent(scope()) -> scope() | ?NIL.
parent(?NIL)  -> ?NIL;
parent(Scope) -> maps:get(parent, Scope).

-spec get(any(), scope()) -> any().
get(Key, Scope) ->
  get(Key, ?NIL, Scope).

-spec get(any(), any(), scope()) -> any().
get(Key, Default, Scope) ->
  do_get(Key, Default, Scope).

-spec contains(any(), scope()) -> boolean().
contains(Key, Scope) ->
  do_contains(Key, Scope).

-spec put(any(), any(), scope()) -> scope().
put(Key, Value, Scope = #{mappings := Mappings}) ->
  Scope#{mappings => Mappings#{Key => Value}}.

-spec put(map(), scope()) -> scope().
put(Map, Scope) ->
  PutFun = fun(Key, Acc) ->
               put(Key, maps:get(Key, Map), Acc)
           end,
  lists:foldl(PutFun, Scope, maps:keys(Map)).

-spec update(any(), any(), scope()) -> scope() | not_found.
update(Key, Value, Scope) ->
  do_update(Key, Value, Scope).

-spec values(scope()) -> [any()].
values(Scope) ->
  do_values([], Scope).

-spec to_map(function(), scope()) -> any().
to_map(Fun, Scope) ->
  do_to_map(Fun, #{}, Scope).

%% @private
-spec do_to_map(function(), map(), scope() | ?NIL) -> map().
do_to_map(_, Map, ?NIL) ->
  Map;
do_to_map(Fun, Map, #{parent := Parent, mappings := Mappings}) ->
  Mappings1 = maps:map(Fun, Mappings),
  do_to_map(Fun, maps:merge(Mappings1, Map), Parent).

%% @private
-spec do_get(any(), any(), scope() | ?NIL) -> any().
do_get(_, Default, ?NIL) ->
  Default;
do_get(Key, Default, Scope = #{mappings := Mappings}) ->
  case Mappings of
    #{Key := Value} -> Value;
    _ -> do_get(Key, Default, parent(Scope))
  end.

%% @private
-spec do_contains(any(), scope() | ?NIL) -> any().
do_contains(_, ?NIL) ->
  false;
do_contains(Key, Scope = #{mappings := Mappings}) ->
  case Mappings of
    #{Key := _} -> true;
    _ -> do_contains(Key, parent(Scope))
  end.

%% @private
-spec do_update(any(), any(), scope() | ?NIL) -> scope() | not_found.
do_update(_K, _V, ?NIL) ->
  not_found;
do_update(K, V, Scope = #{mappings := Mappings, parent := Parent}) ->
  case Mappings of
    #{K := _} ->
      Scope#{mappings => Mappings#{K => V}};
    _ ->
      case do_update(K, V, Parent) of
        not_found -> not_found;
        NewParent -> Scope#{parent => NewParent}
      end
  end.

-spec do_values([any()], scope()) -> [any()].
do_values(Values, ?NIL) ->
  Values;
do_values(Values, #{mappings := Mappings, parent := Parent}) ->
  do_values(maps:values(Mappings) ++ Values, Parent).
