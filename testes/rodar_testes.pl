:- encoding(utf8).

:- ensure_loaded('../src/main').

mapas_teste(['mapa_facil.pl', 'mapa_medio.pl', 'mapa_dificil.pl']).
agentes_teste([logico, aleatorio]).
num_sementes(30).
max_acoes(1000).


%% Uma partida

partida(Agente, Mapa, Semente,
        r(Agente,Mapa,Semente,Pontos,Ouros,Vivo,Acoes,Energia,Motivo)) :-
    set_random(seed(Semente)),
    inicia_jogo(Mapa),
    max_acoes(Max),
    laco(Agente, Max, Motivo),
    estado_ui(_,_,_,Energia,Pontos,Ouros,Acoes),
    ( morto -> Vivo = nao ; Vivo = sim ).

laco(_, _, morreu) :- morto, !.
laco(_, 0, limite_acoes) :- !.
laco(Agente, K, Motivo) :-
    escolhe(Agente, A),
    (   A == fim -> Motivo = encerrou
    ;   passo(A), K1 is K - 1, laco(Agente, K1, Motivo) ).

escolhe(logico, A)    :- executa_acao(A).
escolhe(aleatorio, A) :-
    L = [virar_esquerda, virar_direita, andar, pegar],
    random_between(1, 4, I), nth1(I, L, A).

%% Todas as partidas

rodar_todos :-
    verifica_isolamento,
    mapas_teste(Ms), agentes_teste(As), num_sementes(N),
    findall(R, ( member(Ag, As), member(M, Ms), between(1, N, S),
                 partida(Ag, M, S, R) ), Rs),
    arquivo('resultados.csv', ArqR),
    salva_resultados(ArqR, Rs),
    arquivo('resumo.csv', ArqS),
    resumo(As, Ms, Rs, ArqS),
    format("~nResultados: ~w~nResumo:     ~w~n", [ArqR, ArqS]).

arquivo(Nome, Caminho) :-
    dir_projeto(D), atomic_list_concat([D, '/testes/resultados'], Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/', Nome], Caminho).

salva_resultados(Arq, Rs) :-
    setup_call_cleanup(open(Arq, write, S, [encoding(utf8)]),
      ( format(S, "agente,mapa,semente,pontuacao,ouros,sobreviveu,acoes,energia_final,motivo_fim~n", []),
        forall(member(r(Ag,M,Se,P,O,V,A,E,Mo), Rs),
               format(S, "~w,~w,~w,~w,~w,~w,~w,~w,~w~n", [Ag,M,Se,P,O,V,A,E,Mo])) ),
      close(S)).

resumo(As, Ms, Rs, Arq) :-
    format("~n~w~t~12|~w~t~30|~w~t~42|~w~t~52|~w~t~66|~w~n",
           [agente, mapa, 'pont.media', 'ouro med', 'sobrev. %', 'acoes med']),
    setup_call_cleanup(open(Arq, write, S, [encoding(utf8)]),
      ( format(S, "agente,mapa,partidas,pontuacao_media,pontuacao_min,pontuacao_max,ouros_medio,sobrevivencia_pct,acoes_medias~n", []),
        forall(( member(Ag, As), member(M, Ms) ),
          ( findall(P-O-V-A, member(r(Ag,M,_,P,O,V,A,_,_), Rs), L),
            length(L, N),
            findall(P, member(P-_-_-_, L), Ps), findall(O, member(_-O-_-_, L), Os),
            findall(A, member(_-_-_-A, L), Acs),
            aggregate_all(count, member(_-_-sim-_, L), Vivos),
            media(Ps, MP), media(Os, MO), media(Acs, MA),
            min_list(Ps, MinP), max_list(Ps, MaxP),
            Pct is 100 * Vivos / N,
            format(S, "~w,~w,~w,~2f,~w,~w,~2f,~1f,~1f~n", [Ag,M,N,MP,MinP,MaxP,MO,Pct,MA]),
            format("~w~t~12|~w~t~30|~2f~t~42|~2f~t~52|~1f~t~66|~1f~n", [Ag,M,MP,MO,Pct,MA]) )) ),
      close(S)).

media(L, M) :- sum_list(L, S), length(L, N), M is S / N.

%% O agente não pode ler o mapa real

arquivos_agente(['src/conhecimento/agente_kb.pl', 'src/decisao/agente_decisao.pl']).

verifica_isolamento :-
    dir_projeto(D), arquivos_agente(Fs),
    forall(member(F, Fs),
      ( atomic_list_concat([D, '/', F], Caminho),
        read_file_to_string(Caminho, Txt, [encoding(utf8)]),
        split_string(Txt, "\n", "\r", Linhas),
        (   ( member(Linha, Linhas), sem_comentario(Linha, Codigo),
              sub_string(Codigo, _, _, _, "tile(") )
        ->  format("FALHOU: ~w consulta tile/3 (mapa real)!~n", [F])
        ;   format("OK: ~w nao consulta o mapa real~n", [F]) ) )).

sem_comentario(Linha, Codigo) :-
    (   sub_string(Linha, B, _, _, "%") -> sub_string(Linha, 0, B, _, Codigo)
    ;   Codigo = Linha ).
