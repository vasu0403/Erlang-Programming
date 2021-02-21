-module('2018101074_2').

-compile([export_all]).


get_all_lines(Device) ->
    case io:get_line(Device, "") of
        eof -> [];
        Line -> Line ++ get_all_lines(Device)
    end.


format_edges([],Accum) ->
    Accum;
format_edges([H | T], Accum) ->
    Info = string:tokens(H, " "),
    [U_, V_, W_] = Info,
    U = list_to_integer(U_),
    V = list_to_integer(V_),
    W = list_to_integer(W_),
    format_edges(T, [{U, V, W}, {V, U, W}| Accum]).


file_handling(Args) ->
    [In | Rest] = Args,
    Out = hd(Rest),

    {ok, In_file} = file:open(In, [read]),
    Txt = get_all_lines(In_file),
    Lines = string:tokens(Txt, "\n"),
    
    [NumProcs | Temp1] = Lines,
    [NodesEdges | Temp2] = Temp1,
    Source = lists:last(Temp2),
    [_ | EdgesTxt] = lists:reverse(Temp2),
    Edges = format_edges(EdgesTxt, []),
    
    NodesEdgesTokenized = string:tokens(NodesEdges, " "),
    N = list_to_integer(lists:nth(1, NodesEdgesTokenized)),
    M = list_to_integer(lists:nth(2, NodesEdgesTokenized)),

    {list_to_integer(NumProcs), N, 2*M, Edges, list_to_integer(Source), Out}.

output_result(_, Ind, Size, _) when Ind >= Size ->
    done;
output_result(DistanceCombined, Ind, Size, Fd) when Ind < Size ->
    io:format(Fd, "~p ~p~n", [Ind, array:get(Ind, DistanceCombined)]),
    output_result(DistanceCombined, Ind + 1, Size, Fd).


bellmanUpdates(Distance, [], Update) ->
    {Distance, Update};
bellmanUpdates(Distance, [H | T], Update) ->
    {U, V, W} = H,
    D1 = array:get(U, Distance),
    D2 = array:get(V, Distance),
    
    case ((D1 =/= -1) and ((D2 =:= -1) or (D1 + W < D2))) of
        true ->
            NewDistance = array:set(V, D1 + W, Distance),
            bellmanUpdates(NewDistance, T, true);
        false ->
            bellmanUpdates(Distance, T, Update)
    end. 


combine(_, _, Accum, Ind, Size) when Ind >= Size ->
    Accum;
combine(A1, A2 , Accum, Ind, Size) ->
    H1 = array:get(Ind, A1),
    H2 = array:get(Ind, A2),
    case (((H1 =:= -1) and (H2 =/= -1)) or (((H2 =/= -1) and (H1 > H2)))) of
        true ->
            combine(A1, A2, array:set(Ind, H2, Accum), Ind + 1, Size);
        false ->
            combine(A1, A2, Accum, Ind + 1, Size)
    end.


receiveUpdatesFromAll([], NewDistance, Update) ->
    {NewDistance, Update};
receiveUpdatesFromAll([H | T], NewDistance, Update) ->
    receive
        {bellman_updates, {H, {HisDistance, HisUpdate}}} ->
            UpdatedDistance = combine(NewDistance, HisDistance, NewDistance, 1, array:size(NewDistance)),
            receiveUpdatesFromAll(T, UpdatedDistance, (Update or HisUpdate))
    end.


node(Distance, Edges, ProcNum, Pids, Out) ->
    receive 
        {_, {pids, PidsReceived}} ->
            node(Distance, Edges, ProcNum, PidsReceived, Out);
        {_, start} ->
            {NewDistance, Update} = bellmanUpdates(Distance, Edges, false),
            _ = [X ! {bellman_updates, {self(), {NewDistance, Update}}} || X <- Pids],
            {DistanceCombined, UpdateCombined} = receiveUpdatesFromAll(Pids, NewDistance, Update),
            case (UpdateCombined =:= true) of
                true ->
                    self() ! {self(), start},
                    node(DistanceCombined, Edges, ProcNum, Pids, Out);
                false ->
                    case (ProcNum =:= 1) of 
                        true ->
                            {ok, Fd} = file:open(Out, [write]),
                            output_result(DistanceCombined, 1, array:size(DistanceCombined), Fd),
                            file:close(Fd);
                        false ->
                            do_nothing
                    end
            end
    end.


distribute_graph(_, _, _, Proc, NumProcs, _, _, Pids, _) when Proc > NumProcs ->
    Pids;
distribute_graph(N, M, Edges, Proc, NumProcs, Cur, Distance, Pids, Out) when Proc =< NumProcs ->
    Rem = M rem NumProcs,
    Each = M div NumProcs,
    case Rem >= Proc of
        true -> 
            Take = Each + 1,
            Subset = lists:sublist(Edges, Cur, Take);
        false ->
            Take = Each,
            Subset = lists:sublist(Edges, Cur, Take)
    end,
    Pid = spawn(?MODULE, node, [Distance, Subset, Proc, [], Out]),
    distribute_graph(N, M, Edges, Proc + 1, NumProcs, Cur + Take, Distance, Pids ++ [Pid], Out).


main(Args) ->
    {NumProcs, N, M, Edges, Source, Out} = file_handling(Args),
    DistanceDefault = array:new(N + 1, {default, -1}),
    Distance = array:set(Source, 0, DistanceDefault),
    Pids = distribute_graph(N, M, Edges, 1, NumProcs, 1, Distance, [], Out),
    [Pid ! {self(), {pids, Pids}} || Pid <- Pids],
    [Pid ! {self(), start} || Pid <- Pids].