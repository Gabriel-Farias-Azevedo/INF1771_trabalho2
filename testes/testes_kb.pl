:- encoding(utf8).

:- ensure_loaded('../src/main').
:- use_module(library(plunit)).

mapa_teste(Nome) :-
    atomic_list_concat(['testes/mapas_teste/', Nome, '.pl'], M),
    inicia_jogo(M).

executa(Acoes) :- forall(member(A, Acoes), passo(A)).

:- begin_tests(kb).

test(vizinhos_seguros_sem_percepcao) :-
    mapa_teste(t_poco),
    assertion(seguro(1,2)),
    assertion(seguro(2,1)).

test(brisa_gera_poco_possivel) :-
    mapa_teste(t_poco),
    executa([virar_direita, andar]),
    assertion(perigo_possivel(3,1,poco)),
    assertion(perigo_possivel(2,2,poco)),
    assertion(\+ perigo_certo(3,1,poco)),
    assertion(\+ seguro(3,1)).

test(poco_certo_por_eliminacao) :-
    mapa_teste(t_poco),
    executa([andar, virar_direita, andar,
             virar_direita, andar]),
    assertion(perigo_certo(3,1,poco)),
    assertion(\+ perigo_certo(2,2,poco)),
    assertion(seguro(2,2)).

test(dano_confirma_inimigo) :-
    mapa_teste(t_inimigo),
    executa([andar]),
    assertion(perigo_certo(1,2,inimigo)),
    assertion(\+ seguro(1,2)).

test(teleporte_confirmado) :-
    set_random(seed(7)),
    mapa_teste(t_teleporte),
    executa([andar]),
    assertion(perigo_certo(1,2,teleporte)).

test(brilho_e_reflexo) :-
    mapa_teste(t_ouro),
    executa([andar]),
    assertion(ouro_conhecido(1,2)),
    executa([virar_direita, virar_direita, andar, virar_esquerda, andar]),
    assertion(item_conhecido(2,1)).

test(decide_pegar_ouro) :-
    mapa_teste(t_ouro),
    executa([andar]),
    executa_acao(A),
    assertion(A == pegar),
    passo(pegar),
    assertion(ouros_pegos(1)),
    assertion(\+ ouro_conhecido(1,2)).

test(nao_entra_em_poco_certo) :-
    mapa_teste(t_poco),
    executa([andar, virar_direita, andar, virar_direita, andar]),
    executa([virar_esquerda]),
    executa_acao(A),
    assertion(A \== andar).

:- end_tests(kb).
