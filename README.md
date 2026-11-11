# 1. Instalação

2. **SWI-Prolog (64 bits)**: https://www.swi-prolog.org/download/stable
   Na instalação, marque **"Add swipl to the system PATH"**.
3. **Bibliotecas Python**: no terminal, dentro da pasta do projeto:
   ```
   pip install pygame-ce pyswip
   ```

# 2. Como executar

**Ver o agente jogando nos 3 tipos de mapa** 
```
python src/interface/gmap.py mapa_facil.pl
python src/interface/gmap.py mapa_medio.pl
python src/interface/gmap.py mapa_dificil.pl
```

**Testes das regras de inferência:**
```
swipl -g run_tests -t halt testes/testes_kb.pl
```

**Testes nos 3 mapas** (30 partidas por mapa, gera `testes/resultados/*.csv`):
```
swipl -g rodar_todos -t halt testes/rodar_testes.pl
```

**Partida rápida no terminal, sem interface:**
```
swipl -g "joga('mapa_facil.pl')" -t halt src/main.pl
swipl -g "joga('mapa_medio.pl')" -t halt src/main.pl
swipl -g "joga('mapa_dificil.pl')" -t halt src/main.pl
```