-module(token_ring).
-compile([export_all]).


make_ring([]) ->
    ok;
make_ring([_]) ->
    ok;
make_ring([N1, N2 | Rest]) ->
    N1 ! {self(), {connect, N2}},
    make_ring([N2 | Rest]).


node(ProcNum, Neighbour, Out) ->
    receive
        {_, {connect, N}} ->
            node(ProcNum, N, Out);
        {_, {initiate, Token}} when ProcNum =:= 0 ->
            Neighbour ! {self(), {token, ProcNum, Token}},
            node(ProcNum, Neighbour, Out);
        {_, {token, From, Token}} when ProcNum =/= 0 ->
            {ok, Out_file} = file:open(Out, [append]),
            io:format(Out_file, "Process ~p received token ~p from process ~p\n", [ProcNum, Token, From]),
            Neighbour ! {self(), {token, ProcNum, Token}};
        {_, {token, From, Token}} when ProcNum =:= 0 ->
            {ok, Out_file} = file:open(Out, [append]),
            io:format(Out_file, "Process ~p received token ~p from process ~p\n", [ProcNum, Token, From])
    end.


file_handling(Args) ->
    [In | Rest] = Args,
    Out = hd(Rest),

    {ok, In_file} = file:open(In, [read]),
    {ok, Txt} = file:read(In_file, 1024*1024),
    
    L = string:tokens(Txt, " "),
    NumProcs = list_to_integer(hd(L)),
    Token = list_to_integer(lists:nth(2, L)),

    {NumProcs, Token, Out}.

main(Args) ->

    {NumProcs, Token, Out} = file_handling(Args),
    Pids = [spawn(?MODULE, node, [X, null, Out]) || X <- lists:seq(0, NumProcs - 1)],
    make_ring(Pids ++ [hd(Pids)]),
    hd(Pids) ! {self(), {initiate, Token}}.