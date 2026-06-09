# ⚽ Portfólio SQL: Engenharia Reversa, Normalização e Análise Histórica da Copa do Mundo

> **Atividade Final – Disciplina de Banco de Dados**
> Dataset base: [FIFA World Cup – Kaggle](https://www.kaggle.com/datasets/abecklas/fifa-world-cup)

---

## 📁 Estrutura do Repositório

```
📦 portfolio-sql-copa-do-mundo
 ┣ 📄 dados.db     → Banco SQLite normalizado (836 partidas, 7 tabelas)
 ┣ 📄 script.sql   → DDL completo + 15 consultas analíticas
 ┗ 📄 README.md    → Este arquivo
```

---

## 🎬 Vídeo de Demonstração

> 📹 **[Inserir link do vídeo aqui]**
> A demonstração executa e explica a **Query 13** — que identifica os times
> que chegaram à Final mas nunca conquistaram o título.

---

## 🗂️ Certificados DataCamp

| Curso | Carga Horária | Certificado |
|-------|--------------|-------------|
| Introduction to SQL | 2 horas | [certificados/Introduction to SQL.pdf](certificados/Introduction%20to%20SQL.pdf) |
| Intermediate SQL | 4 horas | [certificados/Intermediate SQL.pdf](certificados/Intermediate%20SQL.pdf) |
| Joining Data in SQL | 4 horas | [certificados/Joining Data in SQL.pdf](certificados/Joining%20Data%20in%20SQL.pdf) |
| Applying SQL to Real-World Problems | 4 horas | [certificados/Applying SQL to Real-World Problems.pdf](certificados/Applying%20SQL%20to%20Real-World%20Problems.pdf) |

---



## 🔄 Modelo Entidade-Relacionamento

### ANTES — Estrutura Bruta do CSV

O arquivo original possui **uma única tabela plana** com 20 colunas e sérios problemas de redundância:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                   WorldCupMatches.csv  (852 linhas reais)                    │
├──────┬────────────────┬────────────┬────────────────┬────────────────────────┤
│ Year │ Stadium        │ City       │ Home Team Name │ Referee                │
├──────┼────────────────┼────────────┼────────────────┼────────────────────────┤
│ 1950 │ Maracanã       │ Rio de Jan.│ Brazil         │ READER George (ENG)    │
│ 1950 │ Maracanã       │ Rio de Jan.│ Uruguay        │ TEJADA Anibal (URU)    │
│ 1950 │ Maracanã       │ Rio de Jan.│ Spain          │ ELLIS Arthur (ENG)     │
│  ↑   │      ↑         │     ↑      │       ↑        │           ↑            │
│ Rep. │ Texto repetido │ Redundante │ Sigla misturada│ Nome+País numa string  │
└──────┴────────────────┴────────────┴────────────────┴────────────────────────┘

Problemas identificados:
  ✗ Nome de cidade repetido em centenas de linhas     (viola a 2FN)
  ✗ Estádio sem entidade própria                      (viola a 2FN)
  ✗ Árbitro como string "NOME (PAÍS)" — não atômico   (viola a 1FN)
  ✗ Sigla do time embutida junto ao nome              (viola a 3FN)
  ✗ 3.720 linhas nulas misturadas às 852 reais
```

---

### DEPOIS — Esquema Normalizado (7 Tabelas)

```
                     ┌─────────────┐
                     │  TB_EDICAO  │
                     │─────────────│
                     │ PK id_edicao│
                     │    ano      │
                     └──────┬──────┘
                            │ 1
                            │ N
┌─────────────┐      ┌──────┴────────────────────────────────────────┐
│  TB_CIDADE  │      │                  TB_PARTIDA                    │
│─────────────│      │───────────────────────────────────────────────│
│ PK id_cidade│◄─┐   │ PK id_partida                                  │
│    nome     │  │   │ FK id_edicao          → TB_EDICAO              │
└──────┬──────┘  │   │ FK id_fase            → TB_FASE                │
       │ 1       │   │ FK id_estadio         → TB_ESTADIO             │
       │ N       └───│ FK id_selecao_mandante → TB_SELECAO            │
┌──────┴──────┐      │ FK id_selecao_visitante→ TB_SELECAO            │
│ TB_ESTADIO  │      │ FK id_arbitro_principal→ TB_ARBITRO            │
│─────────────│      │ FK id_arbitro_assist1 → TB_ARBITRO             │
│ PK id_est.  │◄─────│ FK id_arbitro_assist2 → TB_ARBITRO             │
│    nome     │      │    data_hora                                    │
│ FK id_cidade│      │    gols_mandante                               │
└─────────────┘      │    gols_visitante                              │
                     │    gols_mandante_1tempo                        │
┌─────────────┐      │    gols_visitante_1tempo                       │
│  TB_SELECAO │◄─────│    publico                                     │
│─────────────│      │    condicoes_vitoria                           │
│ PK id_sel.  │      └───────────────────────────────────────────────┘
│    nome     │
│    sigla    │   ┌─────────────┐      ┌─────────────┐
└─────────────┘   │  TB_ARBITRO │      │   TB_FASE   │
                  │─────────────│      │─────────────│
                  │ PK id_arb.  │◄─────│ PK id_fase  │
                  │ nome_compl. │      │   descricao │
                  │ pais_origem │      └─────────────┘
                  └─────────────┘

Formas Normais aplicadas:
  ✓ 1FN — Todos os atributos são atômicos
          (árbitro separado em nome + país de origem)
  ✓ 2FN — Sem dependências parciais
          (cidade é propriedade do estádio, não da partida)
  ✓ 3FN — Sem dependências transitivas
          (sigla é propriedade da seleção, não da partida)
```

---

## 🔎 Dossiê das 15 Consultas

| # | Pergunta de Negócio | Técnicas SQL | Por que é inovadora? |
|---|---|---|---|
| 01 | Quais times fizeram mais gols entre 2002 e 2010? | INNER JOIN, SUM, CASE WHEN, GROUP BY, ORDER BY, LIMIT | Recorte temporal específico revela domínio por era, não apenas histórico geral |
| 02 | Quais países pequenos (até 3 edições) conseguiram vencer jogos e quanto de público foi assistir? | INNER JOIN, SUM, CASE WHEN, COUNT DISTINCT, AVG, GROUP BY, HAVING, ORDER BY, LIMIT | Cruza frequência de participação com vitórias e público — revela zebras históricas que poucos conhecem |
| 03 | Qual foi o melhor desempenho de um país na sua Copa de estreia — gols e público médio? | INNER JOIN, SUM, COUNT, AVG, subconsulta, GROUP BY, HAVING, ORDER BY, LIMIT | Subconsulta identifica o ano de estreia de cada país e analisa seu desempenho naquele momento único |
| 04 | Qual time sofreu mais gols em uma única edição? | INNER JOIN, SUM, CASE WHEN, GROUP BY, ORDER BY, LIMIT | Isola o pior desempenho defensivo dentro de uma Copa específica |
| 05 | Qual Copa teve mais gols no total? | INNER JOIN, SUM, AVG, COUNT, GROUP BY, ORDER BY, LIMIT | Cruza volume de jogos com média por partida, revelando o ritmo ofensivo de cada era |
| 06 | Qual foi o jogo com maior público de todos os tempos? | INNER JOIN (5 tabelas), ORDER BY, LIMIT | Une 5 tabelas para entregar contexto completo — time, estádio, cidade e público |
| 07 | Quais times nunca perderam uma Final? | INNER JOIN, SUM, CASE WHEN, GROUP BY, HAVING, ORDER BY | Analisa invencibilidade em jogos decisivos, não desempenho geral |
| 08 | Qual time ganhou mais jogos fora de casa? | INNER JOIN, SUM, CASE WHEN, GROUP BY, HAVING, ORDER BY, LIMIT | Isola vitórias como visitante — mede resiliência sem apoio da torcida |
| 09 | Qual foi a maior goleada da história? | INNER JOIN, ORDER BY, LIMIT | Traz contexto completo: Copa, fase, times e placar exato da maior diferença já registrada |
| 10 | Quais times se enfrentaram mais vezes? | INNER JOIN, MIN/MAX para deduplicar par, COUNT, SUM, GROUP BY, HAVING, ORDER BY | Reconstrói rivalidades históricas evitando duplicação do par A x B e B x A |
| 11 | Em qual Copa os times empataram mais? | INNER JOIN, SUM, COUNT, ROUND, CAST, GROUP BY, ORDER BY | Usa percentual de empates por Copa, revelando padrões táticos de cada época |
| 12 | Qual time marcou gols em mais edições diferentes? | INNER JOIN, COUNT DISTINCT, SUM, GROUP BY, ORDER BY, LIMIT | COUNT DISTINCT no ano revela presença consistente ao longo de décadas |
| 13 | Quais times chegaram à Final mas nunca ganharam? | INNER JOIN, LEFT OUTER JOIN, subconsulta, GROUP BY, ORDER BY | Subconsulta identifica campeões e os exclui — sobram só os vice-campeões eternos |
| 14 | Qual Copa teve o menor público médio? | INNER JOIN, AVG, MIN, MAX, COUNT, GROUP BY, ORDER BY, LIMIT | Combina média, mínimo e máximo para revelar o perfil de público de cada edição |
| 15 | Qual time venceu mais jogos na fase de grupos? | INNER JOIN, SUM, CASE WHEN, COUNT, GROUP BY, HAVING, ORDER BY, LIMIT | Filtra apenas a fase de grupos usando múltiplos nomes históricos de fase |

---

## 🚀 Como Usar

### Pré-requisitos
- [DBeaver Community](https://dbeaver.io/download/) instalado
- Arquivo `WorldCupMatches.csv` baixado do [Kaggle](https://www.kaggle.com/datasets/abecklas/fifa-world-cup)

### Passo a Passo

**1. Criar o banco**
- Abra o DBeaver → **New Database Connection** → escolha **SQLite**
- Em *Path* clique em **Create** → salve como `dados.db` → **Finish**

**2. Importar o CSV**
- No painel esquerdo, expanda `dados.db` → clique com botão direito em **Tables**
- Clique em **Import Data** → selecione o `WorldCupMatches.csv`
- Em *Target table* escreva `WorldCupMatches` → **Next → Next → Finish**

**3. Rodar o script**
- Menu **SQL Editor → New SQL Script**
- Cole todo o conteúdo do `script.sql`
- **Ctrl+A** para selecionar tudo → **Alt+X** para executar

**4. Verificar**
- TB_PARTIDA deve ter **836 registros**
- Para rodar uma query individual: selecione com o mouse → **Ctrl+Enter**

---

## 📊 Estatísticas do Banco

| Tabela | Registros | Descrição |
|--------|-----------|-----------|
| TB_EDICAO | 20 | Copas de 1930 a 2014 |
| TB_CIDADE | 151 | Cidades-sede únicas |
| TB_ESTADIO | 183 | Estádios vinculados à cidade |
| TB_SELECAO | 83 | Países com sigla extraída |
| TB_ARBITRO | 659 | Árbitros com nome e país separados |
| TB_FASE | 23 | Fases do torneio |
| TB_PARTIDA | 836 | Partidas com 8 chaves estrangeiras |

---

## 🛠️ Tecnologias

![SQLite](https://img.shields.io/badge/SQLite-003B57?style=flat&logo=sqlite&logoColor=white)
![DBeaver](https://img.shields.io/badge/DBeaver-382923?style=flat&logo=dbeaver&logoColor=white)

---

*Projeto desenvolvido para a disciplina de Banco de Dados.*
