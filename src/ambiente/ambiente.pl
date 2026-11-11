:- encoding(utf8).

:- dynamic tile/3.
:- dynamic map_size/2.
:- dynamic mapa_atual/1.
:- dynamic posicao/3.
:- dynamic energia/1.
:- dynamic pontuacao/1.
:- dynamic ouros_coletados/1.
:- dynamic acoes_executadas/1.

% Carrega o arquivo de mapa dinamicamente na base de fatos.

carrega_mapa(Arquivo) :-
    retractall(tile(_,_,_)),
    retractall(map_size(_,_)),
    retractall(mapa_atual(_)),
    setup_call_cleanup(
        open(Arquivo, read, S, [encoding(utf8)]),
        le_termos(S),
        close(S)),
    assertz(mapa_atual(Arquivo)), !.

le_termos(S) :-
    read_term(S, T, []),
    (   T == end_of_file -> true
    ;   guarda_termo(T), le_termos(S) ).

guarda_termo(tile(X,Y,Z))     :- !, assertz(tile(X,Y,Z)).
guarda_termo(map_size(SX,SY)) :- !, assertz(map_size(SX,SY)).
guarda_termo(_).

% Reinicia o estado do ambiente e atualiza energia, pontuação e contadores.

reset_ambiente :-
    ( mapa_atual(M) -> carrega_mapa(M) ; true ),
    retractall(energia(_)), retractall(pontuacao(_)), retractall(posicao(_,_,_)),
    retractall(ouros_coletados(_)), retractall(acoes_executadas(_)),
    assertz(energia(100)),
    assertz(pontuacao(0)),
    assertz(posicao(1,1,norte)),
    assertz(ouros_coletados(0)),
    assertz(acoes_executadas(0)).

morto :- posicao(_,_,morto).

incrementa(Pred) :-
    G =.. [Pred, V], retract(G), NV is V + 1,
    G2 =.. [Pred, NV], assertz(G2).

atualiza_pontuacao(X) :- retract(pontuacao(P)), NP is P + X, assertz(pontuacao(NP)), !.

atualiza_energia(N) :-
    retract(energia(E)), NE0 is E + N,
    (   NE0 =< 0  -> assertz(energia(0)), mata_agente
    ;   NE0 > 100 -> assertz(energia(100))
    ;   assertz(energia(NE0)) ), !.

mata_agente :- retract(posicao(X,Y,_)), assertz(posicao(X,Y,morto)).

% Aplica os efeitos da casa atual sobre o agente (poço, inimigos e teleporte).

verifica_player :- morto, !.
verifica_player :- posicao(X,Y,_), tile(X,Y,'P'),
    atualiza_energia(-100), atualiza_pontuacao(-1000), !.
verifica_player :- posicao(X,Y,_), tile(X,Y,'D'),
    random_between(-80,-50,D), atualiza_energia(D), !.
verifica_player :- posicao(X,Y,_), tile(X,Y,'d'),
    random_between(-50,-25,D), atualiza_energia(D), !.
verifica_player :- posicao(X,Y,Z), tile(X,Y,'T'),
    map_size(SX,SY), random_between(1,SX,NX), random_between(1,SY,NY),
    retract(posicao(X,Y,Z)), assertz(posicao(NX,NY,Z)),
    verifica_player, !.
verifica_player.

% Executa as 4 ações do enunciado: andar, virar_direita, virar_esquerda e pegar.

gira_direita(norte, leste).
gira_direita(leste, sul).
gira_direita(sul, oeste).
gira_direita(oeste, norte).

virar_direita :- \+ morto, retract(posicao(X,Y,D)), gira_direita(D,ND),
    assertz(posicao(X,Y,ND)), atualiza_pontuacao(-1), !.

virar_esquerda :- \+ morto, retract(posicao(X,Y,D)), gira_direita(ND,D),
    assertz(posicao(X,Y,ND)), atualiza_pontuacao(-1), !.

andar :- \+ morto, posicao(X,Y,D), proxima_casa(X,Y,D,NX,NY),
    retract(posicao(X,Y,D)), assertz(posicao(NX,NY,D)),
    atualiza_pontuacao(-1), !.

proxima_casa(X,Y,norte,X,NY) :- map_size(_,MY), Y < MY, NY is Y + 1.
proxima_casa(X,Y,sul,  X,NY) :- Y > 1, NY is Y - 1.
proxima_casa(X,Y,leste,NX,Y) :- map_size(MX,_), X < MX, NX is X + 1.
proxima_casa(X,Y,oeste,NX,Y) :- X > 1, NX is X - 1.

pegar :- \+ morto, posicao(X,Y,_), tile(X,Y,'O'),
    retract(tile(X,Y,'O')), assertz(tile(X,Y,'')),
    atualiza_pontuacao(-5), atualiza_pontuacao(500), incrementa(ouros_coletados), !.
pegar :- \+ morto, posicao(X,Y,_), tile(X,Y,'U'),
    retract(tile(X,Y,'U')), assertz(tile(X,Y,'')),
    atualiza_pontuacao(-5), atualiza_energia(50), !.
pegar :- \+ morto, atualiza_pontuacao(-5), !.

% Sensor do agente: único ponto do código que lê o mapa real (tile/3).

percepcoes(L) :-
    posicao(X,Y,_),
    findall(P, percepcao_em(X,Y,P), L0),
    sort(L0, L).

percepcao_em(X,Y,brilho)  :- tile(X,Y,'O').
percepcao_em(X,Y,reflexo) :- tile(X,Y,'U').
percepcao_em(X,Y,P) :-
    casa_vizinha(X,Y,VX,VY), tile(VX,VY,Z), sinal_de(Z,P).

sinal_de('P', brisa).
sinal_de('T', palmas).
sinal_de('D', passos).
sinal_de('d', passos).

casa_vizinha(X,Y,NX,Y) :- map_size(MX,_), X < MX, NX is X + 1.
casa_vizinha(X,Y,NX,Y) :- X > 1, NX is X - 1.
casa_vizinha(X,Y,X,NY) :- map_size(_,MY), Y < MY, NY is Y + 1.
casa_vizinha(X,Y,X,NY) :- Y > 1, NY is Y - 1.

% Mostra o mapa real no terminal (apenas para depuração, o agente não usa).

show_map :-
    map_size(MX,MY),
    forall(between(1,MY,I),
        ( Y is MY - I + 1,
          forall(between(1,MX,X), ( mostra_casa(X,Y), write('|') )),
          write(Y), nl )),
    energia(E), pontuacao(P), format("E: ~w   P: ~w~n", [E,P]).

mostra_casa(X,Y) :-
    ( posicao(X,Y,D) -> simbolo(D,S) ; S = ' ' ),
    ( tile(X,Y,Z), Z \== '' -> true ; Z = ' ' ),
    format("~w~w", [S,Z]).

simbolo(norte,'^'). simbolo(sul,'v'). simbolo(leste,'>'). simbolo(oeste,'<'). simbolo(morto,'+').
