:- encoding(utf8).

% parametros de comportamento
:- dynamic limite_risco/1, energia_baixa/1, voltar_origem/1.

limite_risco(300).
energia_baixa(50).
voltar_origem(false).
total_ouros(3).

% politica de decisao por prioridade (ordem top-down)
executa_acao(A) :- decide(A0), !, A = A0.

decide(fim) :- posicao(_,_,morto). % morto
decide(pegar) :- posicao(X,Y,_), ouro_conhecido(X,Y). % pegar ouro
decide(pegar) :- % pegar cura
    posicao(X,Y,_), item_conhecido(X,Y),
    energia(E), energia_baixa(L), E =< L.
decide(A) :- ouros_pegos(N), total_ouros(T), N >= T, encerrar(A). % vitoria
decide(A) :- % buscar cura
    energia(E), energia_baixa(L), E =< L,
    proxima_acao(item, seguro, A).
decide(A) :- proxima_acao(explorar, seguro, A). % explorar casa segura
decide(A) :- arriscar(A). % arriscar fronteira
decide(A) :- encerrar(A). % abortar / fallback

% retorna para a origem [1,1] ou encerra
encerrar(A) :-
    voltar_origem(true), posicao(X,Y,_), (X,Y) \= (1,1),
    proxima_acao(celula(1,1), seguro, A), !.
encerrar(fim).

% busca a celula de menor risco na fronteira
arriscar(A) :-
    limite_risco(Lim),
    findall(R-(X,Y),
            ( fronteira(X,Y),
              \+ perigo_certo(X,Y,poco),
              \+ perigo_certo(X,Y,teleporte),
              risco(X,Y,R), R =< Lim ),
            Cands0),
    keysort(Cands0, Cands),
    member(_-(X,Y), Cands),
    proxima_acao(celula(X,Y), seguro_ou(X,Y), A), !.

% planejador bfs (extrai apenas a primeira acao)
proxima_acao(Meta, Passagem, A) :-
    posicao(X,Y,D),
    planeja(X,Y,D, Meta, Passagem, [A|_]).

planeja(X,Y,D, Meta, Passagem, Acoes) :-
    empty_assoc(V0), put_assoc(e(X,Y,D), V0, t, V1),
    bfs([s(X,Y,D,[])], V1, Meta, Passagem, Acoes).

bfs([s(X,Y,_,Rev)|_], _, Meta, _, Acoes) :-
    meta(Meta, X, Y), !, reverse(Rev, Acoes).

bfs([s(X,Y,D,Rev)|Fila], V, Meta, Passagem, Acoes) :-
    findall(s(NX,NY,ND,[A|Rev]),
            ( transicao(X,Y,D, A, NX,NY,ND),
              ( A \== andar -> true ; pode_passar(Passagem, NX, NY) ) ),
            Filhos),
    novos(Filhos, V, V2, Novos),
    append(Fila, Novos, Fila2),
    bfs(Fila2, V2, Meta, Passagem, Acoes).

% atualiza arvore de visitados
novos([], V, V, []).
novos([s(X,Y,D,R)|T], V, V2, Ns) :-
    (   get_assoc(e(X,Y,D), V, _) -> novos(T, V, V2, Ns)
    ;   put_assoc(e(X,Y,D), V, t, V1), Ns = [s(X,Y,D,R)|Ns1], novos(T, V1, V2, Ns1) ).

% transicoes e movimentacao
transicao(X,Y,D, andar,          NX,NY,D)  :- frente(X,Y,D,NX,NY).
transicao(X,Y,D, virar_direita,  X,Y,ND)   :- direita(D,ND).
transicao(X,Y,D, virar_esquerda, X,Y,ND)   :- direita(ND,D).

direita(norte,leste). direita(leste,sul). direita(sul,oeste). direita(oeste,norte).

% metas da busca
meta(explorar, X, Y)      :- \+ visitado(X,Y), seguro(X,Y).
meta(item, X, Y)          :- item_conhecido(X,Y).
meta(celula(TX,TY), X, Y) :- X == TX, Y == TY.

% regras de passagem
pode_passar(seguro, X, Y)           :- seguro(X,Y).
pode_passar(seguro_ou(TX,TY), X, Y) :- ( X == TX, Y == TY -> true ; seguro(X,Y) ).