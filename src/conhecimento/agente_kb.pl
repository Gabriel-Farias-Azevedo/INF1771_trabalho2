:- encoding(utf8).

:- dynamic visitado/2.
:- dynamic percebeu/3.
:- dynamic inimigo_confirmado/2.
:- dynamic teleporte_confirmado/2.
:- dynamic estado_anterior/5.
:- dynamic ouros_pegos/1.

reset_agente :-
    retractall(visitado(_,_)), retractall(percebeu(_,_,_)),
    retractall(inimigo_confirmado(_,_)), retractall(teleporte_confirmado(_,_)),
    retractall(estado_anterior(_,_,_,_,_)), retractall(ouros_pegos(_)),
    assertz(ouros_pegos(0)).

% Verifica os limites do mapa e as posições vizinhas.

casa(X,Y) :- map_size(MX,MY), between(1,MX,X), between(1,MY,Y).

vizinho(X,Y,NX,Y) :- map_size(MX,_), X < MX, NX is X + 1.
vizinho(X,Y,NX,Y) :- X > 1, NX is X - 1.
vizinho(X,Y,X,NY) :- map_size(_,MY), Y < MY, NY is Y + 1.
vizinho(X,Y,X,NY) :- Y > 1, NY is Y - 1.

frente(X,Y,norte,X,NY) :- map_size(_,MY), Y < MY, NY is Y + 1.
frente(X,Y,sul,  X,NY) :- Y > 1, NY is Y - 1.
frente(X,Y,leste,NX,Y) :- map_size(MX,_), X < MX, NX is X + 1.
frente(X,Y,oeste,NX,Y) :- X > 1, NX is X - 1.


% Guarda como o agente estava antes de realizar uma ação para 
% identificar o que mudou depois dela.

agente_antes_acao(A) :-
    retractall(estado_anterior(_,_,_,_,_)),
    posicao(X,Y,D), energia(E),
    assertz(estado_anterior(A,X,Y,D,E)).

% Depois de cada ação registra o que o agente percebeu e marca a casa como visitada.
atualiza_kb :- posicao(_,_,morto), !.
atualiza_kb :-
    posicao(X,Y,_),
    aprende_teleporte(X,Y),
    aprende_dano(X,Y),
    percepcoes(L),
    ( percebeu(X,Y,Antes) -> true ; Antes = [] ),
    retractall(percebeu(X,Y,_)), assertz(percebeu(X,Y,L)),
    aprende_ouro(X,Y,Antes,L),
    ( visitado(X,Y) -> true ; assertz(visitado(X,Y)) ).

aprende_teleporte(X,Y) :-
    estado_anterior(andar,AX,AY,AD,_),
    frente(AX,AY,AD,EX,EY),
    (X,Y) \= (EX,EY), !,
    ( teleporte_confirmado(EX,EY) -> true ; assertz(teleporte_confirmado(EX,EY)) ).
aprende_teleporte(_,_).

aprende_dano(X,Y) :-
    estado_anterior(_,_,_,_,E0), energia(E), E < E0, !,
    ( inimigo_confirmado(X,Y) -> true ; assertz(inimigo_confirmado(X,Y)) ).
aprende_dano(_,_).

aprende_ouro(X,Y,Antes,Depois) :-
    estado_anterior(pegar,X,Y,_,_),
    member(brilho,Antes), \+ member(brilho,Depois), !,
    retract(ouros_pegos(N)), N1 is N + 1, assertz(ouros_pegos(N1)).
aprende_ouro(_,_,_,_).

% Identifica os perigos do mapa a partir das percepções do agente.

sinal(poco,      brisa).
sinal(inimigo,   passos).
sinal(teleporte, palmas).

tipo_perigo(poco). tipo_perigo(inimigo). tipo_perigo(teleporte).

confirmado(X,Y,inimigo)   :- inimigo_confirmado(X,Y).
confirmado(X,Y,teleporte) :- teleporte_confirmado(X,Y).

sem_perigo(X,Y,poco)      :- visitado(X,Y), !.
sem_perigo(X,Y,teleporte) :- visitado(X,Y), !.
sem_perigo(X,Y,inimigo)   :- visitado(X,Y), \+ inimigo_confirmado(X,Y), !.
sem_perigo(X,Y,T) :- confirmado(X,Y,T2), T2 \== T, !.
sem_perigo(X,Y,T) :-
    sinal(T,S), vizinho(X,Y,VX,VY), visitado(VX,VY),
    percebeu(VX,VY,L), \+ member(S,L), !.

seguro(X,Y) :- casa(X,Y), seguro_(X,Y).
seguro_(X,Y) :- visitado(X,Y), !, \+ inimigo_confirmado(X,Y).
seguro_(X,Y) :- sem_perigo(X,Y,poco), sem_perigo(X,Y,inimigo), sem_perigo(X,Y,teleporte).

candidatos(VX,VY,T,Cs) :-
    findall((CX,CY), (vizinho(VX,VY,CX,CY), \+ sem_perigo(CX,CY,T)), Cs).

perigo_certo(X,Y,T) :- confirmado(X,Y,T).
perigo_certo(X,Y,T) :-
    sinal(T,S), visitado(VX,VY), percebeu(VX,VY,L), member(S,L),
    candidatos(VX,VY,T,[(X,Y)]),
    \+ confirmado(X,Y,T).

perigo_possivel(X,Y,T) :- perigo_certo(X,Y,T).
perigo_possivel(X,Y,T) :-
    sinal(T,S), visitado(VX,VY), percebeu(VX,VY,L), member(S,L),
    vizinho(VX,VY,X,Y), \+ sem_perigo(X,Y,T).

ouro_conhecido(X,Y) :- percebeu(X,Y,L), member(brilho,L).
item_conhecido(X,Y) :- percebeu(X,Y,L), member(reflexo,L).

fronteira(X,Y) :-
    casa(X,Y), \+ visitado(X,Y),
    once((vizinho(X,Y,VX,VY), visitado(VX,VY))).

% Calcula o risco de cada posição considerando os perigos conhecidos.

prob_base(0.05).

prob_perigo(X,Y,T,1.0) :- perigo_certo(X,Y,T), !.
prob_perigo(X,Y,T,0.0) :- sem_perigo(X,Y,T), !.
prob_perigo(X,Y,T,P) :-
    sinal(T,S),
    findall(Pi, ( vizinho(X,Y,VX,VY), visitado(VX,VY), percebeu(VX,VY,L),
                  member(S,L), candidatos(VX,VY,T,Cs),
                  prob_por_vizinho(X,Y,T,Cs,Pi) ), Ps),
    ( Ps == [] -> P = 0.0 ; max_list(Ps,P) ).

prob_por_vizinho(X,Y,T,Cs,Pb) :-
    member((CX,CY),Cs), (CX,CY) \= (X,Y), perigo_certo(CX,CY,T), !,
    prob_base(Pb).
prob_por_vizinho(_,_,_,Cs,P) :- length(Cs,K), K > 0, P is 1/K.

custo(poco, 1000).
custo(teleporte, 150).
custo(inimigo, C) :- energia(E),
    ( E > 80 -> C = 60 ; E > 50 -> C = 400; C = 1000 ).

risco(X,Y,R) :-
    findall(Ri, ( tipo_perigo(T), prob_perigo(X,Y,T,P), custo(T,C), Ri is P*C ), Rs),
    sum_list(Rs, R).
