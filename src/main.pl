:- encoding(utf8).

:- ensure_loaded('ambiente/ambiente').
:- ensure_loaded('conhecimento/agente_kb').
:- ensure_loaded('decisao/agente_decisao').

:- dynamic dir_projeto/1.
:- prolog_load_context(directory, Src), file_directory_name(Src, Raiz),
   retractall(dir_projeto(_)), assertz(dir_projeto(Raiz)).

mapa_padrao('mapas/mapa_medio.pl').

% Inicializa o jogo carregando o mapa e reiniciando o ambiente e o agente.

inicia_jogo(Mapa) :-
    resolve_mapa(Mapa, Abs),
    carrega_mapa(Abs),
    reset_ambiente,
    reset_agente,
    atualiza_kb, !.
inicia_jogo :- mapa_padrao(M), inicia_jogo(M).

resolve_mapa(Mapa, Abs) :-
    dir_projeto(Raiz), atomic_list_concat([Raiz, '/mapas'], DirMapas),
    (   absolute_file_name(Mapa, Abs, [relative_to(Raiz), access(read), file_errors(fail)])
    ->  true
    ;   absolute_file_name(Mapa, Abs, [relative_to(DirMapas), access(read)]) ).

% Ciclo percepção -> decisão -> ação: executa a ação, aplica os efeitos e atualiza a KB.

acao_valida(andar).
acao_valida(virar_direita).
acao_valida(virar_esquerda).
acao_valida(pegar).

passo(fim) :- !.
passo(_)   :- morto, !.
passo(A) :-
    acao_valida(A),
    agente_antes_acao(A),
    ( call(A) -> true ; true ),
    incrementa(acoes_executadas),
    verifica_player,
    atualiza_kb, !.

passo_agente(A) :- executa_acao(A), passo(A).

estado_ui(X,Y,D,E,P,O,N) :-
    posicao(X,Y,D), energia(E), pontuacao(P),
    ouros_coletados(O), acoes_executadas(N).

% Executa uma partida completa pelo terminal, sem interface.

joga(Mapa) :- inicia_jogo(Mapa), joga_loop(2000).
joga_loop(0) :- !, writeln('limite de acoes').
joga_loop(K) :-
    executa_acao(A),
    (   A == fim -> resumo
    ;   passo(A), ( morto -> resumo ; K1 is K - 1, joga_loop(K1) ) ).

resumo :- estado_ui(X,Y,D,E,P,O,N),
    format("Fim: pos=(~w,~w,~w) energia=~w pontos=~w ouros=~w acoes=~w~n",[X,Y,D,E,P,O,N]).

:- inicia_jogo.
