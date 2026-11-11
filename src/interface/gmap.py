# Interface grafica do jogo (pygame-ce + pyswip)
# Execucao (a partir da raiz do projeto):
#   python src/interface/gmap.py [mapa]
#   Exemplo: python src/interface/gmap.py mapa_facil.pl

import os
import sys
import pygame
from pyswip import Prolog

# Define a raiz do projeto como diretorio de trabalho
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(RAIZ)

mapa_arquivo = sys.argv[1] if len(sys.argv) > 1 else 'mapa_medio.pl'

auto_play = True
auto_play_tempo = 0.3
show_map = False

scale = 60
size_x = 12
size_y = 12
width = size_x * scale
height = size_y * scale
hud_altura = 60

prolog = Prolog()
prolog.consult(os.path.join(RAIZ, 'src', 'main.pl').replace('\\', '/'))

# Estado atual sincronizado com o Prolog
player_pos = (1, 1, 'norte')
energia = pontuacao = ouros = acoes = 0
last_action = ''
encerrado = False
visitados, seguros = set(), set()
perigos_certos, perigos_possiveis = set(), set()
ouros_conhecidos, itens_conhecidos = set(), set()
mapa_real = {}
elapsed_time = 0


def consulta(q):
    return list(prolog.query(q))


def pares(q):
    return {(r['X'], r['Y']) for r in consulta(q)}


def triplas(q):
    return {(r['X'], r['Y'], str(r['T'])) for r in consulta(q)}


def iniciar():
    global encerrado, last_action
    consulta("inicia_jogo('%s')" % mapa_arquivo)
    encerrado = False
    last_action = ''
    atualiza_estado()


def atualiza_estado():
    global player_pos, energia, pontuacao, ouros, acoes
    global visitados, seguros, perigos_certos, perigos_possiveis
    global ouros_conhecidos, itens_conhecidos, mapa_real

    r = consulta("estado_ui(X,Y,D,E,P,O,N)")[0]
    player_pos = (r['X'], r['Y'], str(r['D']))
    energia, pontuacao, ouros, acoes = r['E'], r['P'], r['O'], r['N']

    visitados = pares("visitado(X,Y)")
    seguros = pares("seguro(X,Y)")
    perigos_certos = triplas("perigo_certo(X,Y,T)")
    perigos_possiveis = triplas("perigo_possivel(X,Y,T)") - perigos_certos
    ouros_conhecidos = pares("ouro_conhecido(X,Y)")
    itens_conhecidos = pares("item_conhecido(X,Y)")

    mapa_real = {}
    if show_map:
        for t in consulta("tile(X,Y,Z)"):
            mapa_real[(t['X'], t['Y'])] = str(t['Z'])


def executa(acao):
    global last_action
    consulta("passo(%s)" % acao)
    last_action = acao
    atualiza_estado()


def passo_automatico():
    global encerrado, last_action
    acao = str(consulta("executa_acao(X)")[0]['X'])
    if acao == 'fim':
        encerrado = True
        last_action = 'fim'
    else:
        executa(acao)


def carrega_img(nome):
    img_surface = pygame.image.load(os.path.join('image', nome))
    return pygame.transform.scale(img_surface, (scale, scale))


def load():
    global sys_font, clock, img
    sys_font = pygame.font.Font(pygame.font.get_default_font(), 18)
    clock = pygame.time.Clock()
    nomes = ['floor', 'gold', 'health', 'pit', 'bat', 'enemy1', 'enemy2',
             'player_up', 'player_down', 'player_left', 'player_right', 'tombstone']
    img = {n: carrega_img(n + '.png') for n in nomes}
    for n in ['floor', 'gold', 'health', 'pit', 'bat', 'enemy1', 'enemy2']:
        img['bw_' + n] = carrega_img('bw_' + n + '.png')


IMG_PERIGO = {'poco': 'pit', 'teleporte': 'bat', 'inimigo': 'enemy1'}
IMG_TILE = {'P': 'pit', 'T': 'bat', 'D': 'enemy1', 'd': 'enemy2', 'U': 'health', 'O': 'gold'}
IMG_PLAYER = {'norte': 'player_up', 'sul': 'player_down',
              'leste': 'player_right', 'oeste': 'player_left'}


def tela(x, y):
    return ((x - 1) * scale, (size_y - y) * scale)


def draw_screen(screen):
    screen.fill((0, 0, 0))

    for x in range(1, size_x + 1):
        for y in range(1, size_y + 1):
            p = tela(x, y)
            screen.blit(img['floor'] if (x, y) in visitados else img['bw_floor'], p)

            if show_map:
                z = mapa_real.get((x, y), '')
                if z in IMG_TILE:
                    screen.blit(img[IMG_TILE[z]], p)
                continue

            if (x, y) in seguros and (x, y) not in visitados:
                pygame.draw.rect(screen, (60, 200, 90), (*p, scale, scale), 3)

            for (px, py, t) in perigos_possiveis:
                if (px, py) == (x, y):
                    screen.blit(img['bw_' + IMG_PERIGO[t]], p)
            for (px, py, t) in perigos_certos:
                if (px, py) == (x, y):
                    screen.blit(img[IMG_PERIGO[t]], p)
            if (x, y) in ouros_conhecidos:
                screen.blit(img['gold'], p)
            if (x, y) in itens_conhecidos:
                screen.blit(img['health'], p)

    x, y, d = player_pos
    screen.blit(img[IMG_PLAYER.get(d, 'tombstone')], tela(x, y))

    branco = (255, 255, 255)
    linha1 = "Pontuação: %s    Energia: %s    Ouros: %s/3    Ações: %s" % (pontuacao, energia, ouros, acoes)
    if d == 'morto':
        status = "MORREU - pontuação final: %s" % pontuacao
    elif encerrado:
        status = "FIM - pontuação final: %s" % pontuacao
    else:
        status = "Última ação: %s   |   modo: %s   |   mapa: %s%s" % (
            last_action, 'automático' if auto_play else 'manual', mapa_arquivo,
            '   |   MAPA REAL' if show_map else '')
    screen.blit(sys_font.render(linha1, True, branco), (10, height + 8))
    screen.blit(sys_font.render(status, True, branco), (10, height + 34))


def update(dt):
    global elapsed_time
    elapsed_time += dt
    if elapsed_time / 1000 > auto_play_tempo:
        if auto_play and not encerrado and player_pos[2] != 'morto':
            passo_automatico()
        elapsed_time = 0


def key_pressed(event):
    global show_map, auto_play
    if event.type != pygame.KEYDOWN:
        return
    if not auto_play and not encerrado and player_pos[2] != 'morto':
        if event.key == pygame.K_LEFT:
            executa('virar_esquerda')
        elif event.key == pygame.K_RIGHT:
            executa('virar_direita')
        elif event.key == pygame.K_UP:
            executa('andar')
        elif event.key == pygame.K_SPACE:
            executa('pegar')
    if event.key == pygame.K_a:
        auto_play = not auto_play
    elif event.key == pygame.K_m:
        show_map = not show_map
        atualiza_estado()
    elif event.key == pygame.K_r:
        iniciar()


def main_loop(screen, max_frames=None):
    running, frames = True, 0
    while running:
        for e in pygame.event.get():
            if e.type == pygame.QUIT:
                running = False
                break
            key_pressed(e)
        dt = clock.tick(60)
        update(dt)
        draw_screen(screen)
        pygame.display.update()
        frames += 1
        if max_frames and frames >= max_frames:
            running = False


if __name__ == '__main__':
    iniciar()
    pygame.init()
    pygame.display.set_caption('INF1771 Trabalho 2 - Agente Lógico - ' + mapa_arquivo)
    screen = pygame.display.set_mode((width, height + hud_altura))
    load()
    main_loop(screen)
    pygame.quit()
