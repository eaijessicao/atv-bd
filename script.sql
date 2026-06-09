-- ============================================================================
--  PORTFÓLIO SQL – Copa do Mundo FIFA
--  Engenharia Reversa, Normalização e Análise Histórica
-- ============================================================================
--  SGBD : SQLite 3  |  Interface: DBeaver
--  Tabela bruta importada via DBeaver: WorldCupMatches
--
--  Como usar:
--    1. Importe WorldCupMatches.csv pelo assistente do DBeaver
--    2. Abra este script no SQL Editor
--    3. Selecione tudo (Ctrl+A) e execute (Ctrl+Enter)
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ============================================================================
-- PASSO 1 — REMOVE TABELAS ANTERIORES
-- ============================================================================
DROP TABLE IF EXISTS TB_PARTIDA;
DROP TABLE IF EXISTS TB_ESTADIO;
DROP TABLE IF EXISTS TB_ARBITRO;
DROP TABLE IF EXISTS TB_SELECAO;
DROP TABLE IF EXISTS TB_FASE;
DROP TABLE IF EXISTS TB_CIDADE;
DROP TABLE IF EXISTS TB_EDICAO;

-- ============================================================================
-- PASSO 2 — DDL: CRIAÇÃO DAS TABELAS NORMALIZADAS
-- ============================================================================

-- Cada edição da Copa do Mundo
-- 1FN: ano é atômico e único, sem repetição de dados
CREATE TABLE TB_EDICAO (
    id_edicao   INTEGER PRIMARY KEY AUTOINCREMENT,
    ano         INTEGER NOT NULL UNIQUE
);

-- Cidades-sede
-- Elimina a repetição do nome da cidade em cada linha de partida
CREATE TABLE TB_CIDADE (
    id_cidade   INTEGER PRIMARY KEY AUTOINCREMENT,
    nome        TEXT NOT NULL UNIQUE
);

-- Estádios vinculados à cidade
-- 2FN: cidade era dependência transitória da partida no CSV, agora é FK do estádio
CREATE TABLE TB_ESTADIO (
    id_estadio  INTEGER PRIMARY KEY AUTOINCREMENT,
    nome        TEXT NOT NULL,
    id_cidade   INTEGER NOT NULL,
    FOREIGN KEY (id_cidade) REFERENCES TB_CIDADE(id_cidade),
    UNIQUE (nome, id_cidade)
);

-- Seleções com sigla separada do nome
-- 3FN: a sigla dependia transitivamente da partida via nome do time
CREATE TABLE TB_SELECAO (
    id_selecao  INTEGER PRIMARY KEY AUTOINCREMENT,
    nome        TEXT NOT NULL UNIQUE,
    sigla       TEXT
);

-- Árbitros com país de origem extraído
-- 1FN: no CSV vinham como string única "NOME Sobrenome (PAIS)"
CREATE TABLE TB_ARBITRO (
    id_arbitro      INTEGER PRIMARY KEY AUTOINCREMENT,
    nome_completo   TEXT NOT NULL UNIQUE,
    pais_origem     TEXT
);

-- Fases do torneio
-- Elimina texto repetido linha a linha no CSV
CREATE TABLE TB_FASE (
    id_fase     INTEGER PRIMARY KEY AUTOINCREMENT,
    descricao   TEXT NOT NULL UNIQUE
);

-- Tabela de fatos — apenas valores atômicos e FKs
-- Todos os atributos dependem unicamente de id_partida (2FN e 3FN satisfeitas)
CREATE TABLE TB_PARTIDA (
    id_partida              INTEGER PRIMARY KEY,
    id_edicao               INTEGER NOT NULL,
    id_fase                 INTEGER NOT NULL,
    id_estadio              INTEGER,
    id_selecao_mandante     INTEGER NOT NULL,
    id_selecao_visitante    INTEGER NOT NULL,
    id_arbitro_principal    INTEGER,
    id_arbitro_assistente1  INTEGER,
    id_arbitro_assistente2  INTEGER,
    data_hora               TEXT,
    gols_mandante           INTEGER NOT NULL DEFAULT 0,
    gols_visitante          INTEGER NOT NULL DEFAULT 0,
    gols_mandante_1tempo    INTEGER,
    gols_visitante_1tempo   INTEGER,
    publico                 REAL,
    condicoes_vitoria       TEXT,
    FOREIGN KEY (id_edicao)               REFERENCES TB_EDICAO(id_edicao),
    FOREIGN KEY (id_fase)                 REFERENCES TB_FASE(id_fase),
    FOREIGN KEY (id_estadio)              REFERENCES TB_ESTADIO(id_estadio),
    FOREIGN KEY (id_selecao_mandante)     REFERENCES TB_SELECAO(id_selecao),
    FOREIGN KEY (id_selecao_visitante)    REFERENCES TB_SELECAO(id_selecao),
    FOREIGN KEY (id_arbitro_principal)    REFERENCES TB_ARBITRO(id_arbitro),
    FOREIGN KEY (id_arbitro_assistente1)  REFERENCES TB_ARBITRO(id_arbitro),
    FOREIGN KEY (id_arbitro_assistente2)  REFERENCES TB_ARBITRO(id_arbitro)
);

-- ============================================================================
-- PASSO 3 — DML: POPULA AS DIMENSÕES A PARTIR DA TABELA BRUTA
-- ============================================================================

INSERT INTO TB_EDICAO (ano)
SELECT DISTINCT CAST("Year" AS INTEGER)
FROM WorldCupMatches
WHERE "Year" IS NOT NULL AND TRIM("Year") <> ''
ORDER BY CAST("Year" AS INTEGER);

INSERT INTO TB_CIDADE (nome)
SELECT DISTINCT TRIM("City")
FROM WorldCupMatches
WHERE "City" IS NOT NULL AND TRIM("City") <> ''
ORDER BY TRIM("City");

INSERT INTO TB_ESTADIO (nome, id_cidade)
SELECT DISTINCT TRIM(w."Stadium"), c.id_cidade
FROM WorldCupMatches w
INNER JOIN TB_CIDADE c ON c.nome = TRIM(w."City")
WHERE w."Stadium" IS NOT NULL AND TRIM(w."Stadium") <> ''
ORDER BY TRIM(w."Stadium");

INSERT INTO TB_SELECAO (nome, sigla)
SELECT nome, sigla FROM (
    SELECT DISTINCT TRIM("Home Team Name") AS nome, TRIM("Home Team Initials") AS sigla
    FROM WorldCupMatches
    WHERE "Home Team Name" IS NOT NULL AND TRIM("Home Team Name") <> ''
    UNION
    SELECT DISTINCT TRIM("Away Team Name"), TRIM("Away Team Initials")
    FROM WorldCupMatches
    WHERE "Away Team Name" IS NOT NULL AND TRIM("Away Team Name") <> ''
)
ORDER BY nome;

INSERT INTO TB_FASE (descricao)
SELECT DISTINCT TRIM("Stage")
FROM WorldCupMatches
WHERE "Stage" IS NOT NULL AND TRIM("Stage") <> ''
ORDER BY TRIM("Stage");

INSERT OR IGNORE INTO TB_ARBITRO (nome_completo, pais_origem)
SELECT
    TRIM(SUBSTR("Referee", 1, INSTR("Referee", '(') - 1)),
    TRIM(REPLACE(REPLACE(SUBSTR("Referee", INSTR("Referee", '(')), '(', ''), ')', ''))
FROM WorldCupMatches
WHERE "Referee" IS NOT NULL
  AND TRIM("Referee") <> ''
  AND INSTR("Referee", '(') > 0
GROUP BY TRIM(SUBSTR("Referee", 1, INSTR("Referee", '(') - 1));

INSERT OR IGNORE INTO TB_ARBITRO (nome_completo, pais_origem)
SELECT
    TRIM(SUBSTR("Assistant 1", 1, INSTR("Assistant 1", '(') - 1)),
    TRIM(REPLACE(REPLACE(SUBSTR("Assistant 1", INSTR("Assistant 1", '(')), '(', ''), ')', ''))
FROM WorldCupMatches
WHERE "Assistant 1" IS NOT NULL
  AND TRIM("Assistant 1") <> ''
  AND INSTR("Assistant 1", '(') > 0
GROUP BY TRIM(SUBSTR("Assistant 1", 1, INSTR("Assistant 1", '(') - 1));

INSERT OR IGNORE INTO TB_ARBITRO (nome_completo, pais_origem)
SELECT
    TRIM(SUBSTR("Assistant 2", 1, INSTR("Assistant 2", '(') - 1)),
    TRIM(REPLACE(REPLACE(SUBSTR("Assistant 2", INSTR("Assistant 2", '(')), '(', ''), ')', ''))
FROM WorldCupMatches
WHERE "Assistant 2" IS NOT NULL
  AND TRIM("Assistant 2") <> ''
  AND INSTR("Assistant 2", '(') > 0
GROUP BY TRIM(SUBSTR("Assistant 2", 1, INSTR("Assistant 2", '(') - 1));

-- ============================================================================
-- PASSO 4 — POPULA TB_PARTIDA
-- ============================================================================
INSERT OR IGNORE INTO TB_PARTIDA (
    id_partida, id_edicao, id_fase, id_estadio,
    id_selecao_mandante, id_selecao_visitante,
    id_arbitro_principal, id_arbitro_assistente1, id_arbitro_assistente2,
    data_hora, gols_mandante, gols_visitante,
    gols_mandante_1tempo, gols_visitante_1tempo,
    publico, condicoes_vitoria
)
SELECT
    CAST(w."MatchID" AS INTEGER),
    e.id_edicao,
    f.id_fase,
    est.id_estadio,
    sm.id_selecao,
    sv.id_selecao,
    arb.id_arbitro,
    a1.id_arbitro,
    a2.id_arbitro,
    TRIM(w."Datetime"),
    CAST(w."Home Team Goals"      AS INTEGER),
    CAST(w."Away Team Goals"      AS INTEGER),
    CAST(w."Half-time Home Goals" AS INTEGER),
    CAST(w."Half-time Away Goals" AS INTEGER),
    CAST(w."Attendance"           AS REAL),
    CASE WHEN TRIM(w."Win conditions") = '' THEN NULL
         ELSE TRIM(w."Win conditions") END
FROM WorldCupMatches w
INNER JOIN TB_EDICAO  e   ON e.ano          = CAST(w."Year" AS INTEGER)
INNER JOIN TB_FASE    f   ON f.descricao    = TRIM(w."Stage")
INNER JOIN TB_ESTADIO est ON est.nome       = TRIM(w."Stadium")
INNER JOIN TB_CIDADE  cid ON cid.id_cidade  = est.id_cidade
                          AND cid.nome      = TRIM(w."City")
INNER JOIN TB_SELECAO sm  ON sm.nome        = TRIM(w."Home Team Name")
INNER JOIN TB_SELECAO sv  ON sv.nome        = TRIM(w."Away Team Name")
LEFT  JOIN TB_ARBITRO arb ON arb.nome_completo =
    TRIM(SUBSTR(w."Referee", 1, INSTR(w."Referee", '(') - 1))
LEFT  JOIN TB_ARBITRO a1  ON a1.nome_completo =
    TRIM(SUBSTR(w."Assistant 1", 1, INSTR(w."Assistant 1", '(') - 1))
LEFT  JOIN TB_ARBITRO a2  ON a2.nome_completo =
    TRIM(SUBSTR(w."Assistant 2", 1, INSTR(w."Assistant 2", '(') - 1))
WHERE w."Year"    IS NOT NULL AND TRIM(w."Year")    <> ''
  AND w."MatchID" IS NOT NULL AND TRIM(w."MatchID") <> '';

-- ============================================================================
-- PASSO 5 — VERIFICAÇÃO
-- ============================================================================
SELECT 'TB_EDICAO'  AS tabela, COUNT(*) AS registros FROM TB_EDICAO  UNION ALL
SELECT 'TB_CIDADE',             COUNT(*)              FROM TB_CIDADE  UNION ALL
SELECT 'TB_ESTADIO',            COUNT(*)              FROM TB_ESTADIO UNION ALL
SELECT 'TB_SELECAO',            COUNT(*)              FROM TB_SELECAO UNION ALL
SELECT 'TB_ARBITRO',            COUNT(*)              FROM TB_ARBITRO UNION ALL
SELECT 'TB_FASE',               COUNT(*)              FROM TB_FASE    UNION ALL
SELECT 'TB_PARTIDA',            COUNT(*)              FROM TB_PARTIDA;

-- ============================================================================
-- 15 CONSULTAS ANALÍTICAS
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 01
-- Quais times fizeram mais gols entre 2002 e 2010?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    s.nome                                          AS time,
    SUM(
        CASE WHEN p.id_selecao_mandante = s.id_selecao
             THEN p.gols_mandante ELSE p.gols_visitante END
    )                                               AS total_gols
FROM TB_PARTIDA p
INNER JOIN TB_SELECAO s
    ON s.id_selecao IN (p.id_selecao_mandante, p.id_selecao_visitante)
INNER JOIN TB_EDICAO e ON e.id_edicao = p.id_edicao
WHERE e.ano BETWEEN 2002 AND 2010
GROUP BY s.id_selecao
ORDER BY total_gols DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 02
-- Quais países pequenos (até 3 edições) conseguiram vencer jogos na Copa
-- e quanto de público foi assistir?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    s.nome                                                          AS pais,
    COUNT(DISTINCT e.ano)                                           AS edicoes_disputadas,
    SUM(CASE
        WHEN p.id_selecao_mandante  = s.id_selecao
         AND p.gols_mandante > p.gols_visitante  THEN 1
        WHEN p.id_selecao_visitante = s.id_selecao
         AND p.gols_visitante > p.gols_mandante  THEN 1
        ELSE 0 END)                                                 AS vitorias,
    ROUND(AVG(p.publico), 0)                                        AS media_publico_nos_jogos
FROM TB_PARTIDA p
INNER JOIN TB_SELECAO s
    ON s.id_selecao IN (p.id_selecao_mandante, p.id_selecao_visitante)
INNER JOIN TB_EDICAO e ON e.id_edicao = p.id_edicao
GROUP BY s.id_selecao
HAVING edicoes_disputadas <= 3
   AND vitorias > 0
ORDER BY vitorias DESC, media_publico_nos_jogos DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 03
-- Qual foi o melhor desempenho de um país na sua Copa de estreia —
-- gols marcados e público médio nos seus jogos?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    s.nome                                                          AS pais,
    MIN(e.ano)                                                      AS ano_estreia,
    COUNT(p.id_partida)                                             AS jogos_na_estreia,
    SUM(CASE WHEN p.id_selecao_mandante  = s.id_selecao
             THEN p.gols_mandante ELSE p.gols_visitante END)        AS gols_marcados,
    SUM(CASE WHEN p.id_selecao_mandante  = s.id_selecao
             THEN p.gols_visitante ELSE p.gols_mandante END)        AS gols_sofridos,
    ROUND(AVG(p.publico), 0)                                        AS media_publico
FROM TB_PARTIDA p
INNER JOIN TB_SELECAO s
    ON s.id_selecao IN (p.id_selecao_mandante, p.id_selecao_visitante)
INNER JOIN TB_EDICAO e ON e.id_edicao = p.id_edicao
WHERE e.ano = (
    SELECT MIN(e2.ano)
    FROM TB_PARTIDA p2
    INNER JOIN TB_EDICAO e2 ON e2.id_edicao = p2.id_edicao
    WHERE p2.id_selecao_mandante  = s.id_selecao
       OR p2.id_selecao_visitante = s.id_selecao
)
GROUP BY s.id_selecao
HAVING gols_marcados >= 5
ORDER BY gols_marcados DESC, media_publico DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 04
-- Qual time sofreu mais gols em uma única edição da Copa?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    s.nome                                          AS time,
    e.ano                                           AS copa,
    SUM(
        CASE WHEN p.id_selecao_mandante = s.id_selecao
             THEN p.gols_visitante ELSE p.gols_mandante END
    )                                               AS gols_sofridos
FROM TB_PARTIDA p
INNER JOIN TB_SELECAO s
    ON s.id_selecao IN (p.id_selecao_mandante, p.id_selecao_visitante)
INNER JOIN TB_EDICAO e ON e.id_edicao = p.id_edicao
GROUP BY s.id_selecao, e.ano
ORDER BY gols_sofridos DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 05
-- Qual Copa teve mais gols no total?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    e.ano                                               AS copa,
    COUNT(p.id_partida)                                 AS total_jogos,
    SUM(p.gols_mandante + p.gols_visitante)             AS total_gols,
    ROUND(AVG(p.gols_mandante + p.gols_visitante), 2)   AS media_gols_por_jogo
FROM TB_PARTIDA p
INNER JOIN TB_EDICAO e ON e.id_edicao = p.id_edicao
GROUP BY e.ano
ORDER BY total_gols DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 06
-- Qual foi o jogo com maior público de todos os tempos?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    e.ano                   AS copa,
    sm.nome                 AS mandante,
    sv.nome                 AS visitante,
    p.gols_mandante         AS gols_mandante,
    p.gols_visitante        AS gols_visitante,
    est.nome                AS estadio,
    c.nome                  AS cidade,
    p.publico               AS publico
FROM TB_PARTIDA p
INNER JOIN TB_EDICAO  e   ON e.id_edicao    = p.id_edicao
INNER JOIN TB_SELECAO sm  ON sm.id_selecao  = p.id_selecao_mandante
INNER JOIN TB_SELECAO sv  ON sv.id_selecao  = p.id_selecao_visitante
INNER JOIN TB_ESTADIO est ON est.id_estadio = p.id_estadio
INNER JOIN TB_CIDADE  c   ON c.id_cidade    = est.id_cidade
WHERE p.publico IS NOT NULL
ORDER BY p.publico DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 07
-- Quais times nunca perderam uma Final de Copa do Mundo?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    s.nome                                                          AS time,
    COUNT(p.id_partida)                                             AS finais_disputadas,
    SUM(CASE
        WHEN p.id_selecao_mandante = s.id_selecao
         AND p.gols_mandante > p.gols_visitante  THEN 1
        WHEN p.id_selecao_visitante = s.id_selecao
         AND p.gols_visitante > p.gols_mandante  THEN 1
        WHEN p.condicoes_vitoria IS NOT NULL
         AND INSTR(LOWER(p.condicoes_vitoria), LOWER(s.nome)) > 0  THEN 1
        ELSE 0 END)                                                 AS titulos,
    SUM(CASE
        WHEN p.id_selecao_mandante = s.id_selecao
         AND p.gols_mandante < p.gols_visitante  THEN 1
        WHEN p.id_selecao_visitante = s.id_selecao
         AND p.gols_visitante < p.gols_mandante  THEN 1
        WHEN p.condicoes_vitoria IS NOT NULL
         AND INSTR(LOWER(p.condicoes_vitoria), LOWER(s.nome)) = 0  THEN 1
        ELSE 0 END)                                                 AS derrotas_em_finais
FROM TB_PARTIDA p
INNER JOIN TB_FASE    f ON f.id_fase    = p.id_fase
INNER JOIN TB_SELECAO s
    ON s.id_selecao IN (p.id_selecao_mandante, p.id_selecao_visitante)
WHERE f.descricao = 'Final'
GROUP BY s.id_selecao
HAVING derrotas_em_finais = 0
ORDER BY titulos DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 08
-- Qual time ganhou mais jogos jogando fora de casa?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    s.nome                                                          AS time,
    COUNT(p.id_partida)                                             AS jogos_fora,
    SUM(CASE WHEN p.gols_visitante > p.gols_mandante THEN 1
             ELSE 0 END)                                            AS vitorias_fora
FROM TB_PARTIDA p
INNER JOIN TB_SELECAO s ON s.id_selecao = p.id_selecao_visitante
GROUP BY s.id_selecao
HAVING jogos_fora >= 5
ORDER BY vitorias_fora DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 09
-- Qual foi a maior goleada da história da Copa?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    e.ano                                       AS copa,
    sm.nome                                     AS vencedor,
    sv.nome                                     AS perdedor,
    p.gols_mandante                             AS gols_vencedor,
    p.gols_visitante                            AS gols_perdedor,
    (p.gols_mandante - p.gols_visitante)        AS diferenca,
    f.descricao                                 AS fase
FROM TB_PARTIDA p
INNER JOIN TB_EDICAO  e  ON e.id_edicao   = p.id_edicao
INNER JOIN TB_SELECAO sm ON sm.id_selecao = p.id_selecao_mandante
INNER JOIN TB_SELECAO sv ON sv.id_selecao = p.id_selecao_visitante
INNER JOIN TB_FASE    f  ON f.id_fase     = p.id_fase
WHERE p.gols_mandante > p.gols_visitante
ORDER BY diferenca DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 10
-- Quais times se enfrentaram mais vezes na história da Copa?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    s1.nome                                     AS time_a,
    s2.nome                                     AS time_b,
    COUNT(p.id_partida)                         AS confrontos,
    SUM(p.gols_mandante + p.gols_visitante)     AS total_gols_nos_confrontos
FROM TB_PARTIDA p
INNER JOIN TB_SELECAO s1
    ON s1.id_selecao = MIN(p.id_selecao_mandante, p.id_selecao_visitante)
INNER JOIN TB_SELECAO s2
    ON s2.id_selecao = MAX(p.id_selecao_mandante, p.id_selecao_visitante)
GROUP BY s1.id_selecao, s2.id_selecao
HAVING confrontos >= 3
ORDER BY confrontos DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 11
-- Em qual Copa os times empataram mais?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    e.ano                                           AS copa,
    COUNT(p.id_partida)                             AS total_jogos,
    SUM(CASE WHEN p.gols_mandante = p.gols_visitante
             THEN 1 ELSE 0 END)                     AS empates,
    ROUND(
        CAST(SUM(CASE WHEN p.gols_mandante = p.gols_visitante
                      THEN 1 ELSE 0 END) AS REAL)
        / COUNT(p.id_partida) * 100, 1)             AS pct_empates
FROM TB_PARTIDA p
INNER JOIN TB_EDICAO e ON e.id_edicao = p.id_edicao
GROUP BY e.ano
ORDER BY pct_empates DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 12
-- Qual time marcou gols em mais edições diferentes da Copa?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    s.nome                          AS time,
    COUNT(DISTINCT e.ano)           AS copas_em_que_marcou,
    SUM(
        CASE WHEN p.id_selecao_mandante = s.id_selecao
             THEN p.gols_mandante ELSE p.gols_visitante END
    )                               AS total_gols_historico
FROM TB_PARTIDA p
INNER JOIN TB_SELECAO s
    ON s.id_selecao IN (p.id_selecao_mandante, p.id_selecao_visitante)
INNER JOIN TB_EDICAO e ON e.id_edicao = p.id_edicao
WHERE (
    CASE WHEN p.id_selecao_mandante = s.id_selecao
         THEN p.gols_mandante ELSE p.gols_visitante END
) > 0
GROUP BY s.id_selecao
ORDER BY copas_em_que_marcou DESC, total_gols_historico DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 13
-- Quais times chegaram à Final mas nunca ganharam o título?
-- LEFT OUTER JOIN garante que todas as seleções sejam consideradas,
-- inclusive as que não aparecem em nenhuma Final — o WHERE filtra só as que aparecem.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    s.nome                          AS time,
    COUNT(p.id_partida)             AS finais_disputadas
FROM TB_SELECAO s
LEFT OUTER JOIN TB_PARTIDA p
    ON (p.id_selecao_mandante  = s.id_selecao
    OR  p.id_selecao_visitante = s.id_selecao)
LEFT OUTER JOIN TB_FASE f
    ON f.id_fase = p.id_fase
    AND f.descricao = 'Final'
WHERE f.id_fase IS NOT NULL
  AND s.id_selecao NOT IN (
      -- Subconsulta: identifica os times que já venceram pelo menos uma Final
      SELECT
          CASE WHEN pf.gols_mandante > pf.gols_visitante
               THEN pf.id_selecao_mandante
               WHEN pf.gols_visitante > pf.gols_mandante
               THEN pf.id_selecao_visitante
               WHEN pf.condicoes_vitoria IS NOT NULL
                AND INSTR(LOWER(pf.condicoes_vitoria),
                    LOWER((SELECT nome FROM TB_SELECAO
                           WHERE id_selecao = pf.id_selecao_mandante))) > 0
               THEN pf.id_selecao_mandante
               ELSE pf.id_selecao_visitante
          END
      FROM TB_PARTIDA pf
      INNER JOIN TB_FASE ff ON ff.id_fase = pf.id_fase
      WHERE ff.descricao = 'Final'
  )
GROUP BY s.id_selecao
ORDER BY finais_disputadas DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 14
-- Qual Copa teve o menor público médio por jogo?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    e.ano                               AS copa,
    COUNT(p.id_partida)                 AS jogos_com_publico,
    ROUND(AVG(p.publico), 0)            AS media_publico,
    MIN(p.publico)                      AS menor_publico,
    MAX(p.publico)                      AS maior_publico
FROM TB_PARTIDA p
INNER JOIN TB_EDICAO e ON e.id_edicao = p.id_edicao
WHERE p.publico IS NOT NULL
GROUP BY e.ano
ORDER BY media_publico ASC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 15
-- Qual time venceu mais jogos na fase de grupos?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    s.nome                                                          AS time,
    COUNT(p.id_partida)                                             AS jogos_na_fase_de_grupos,
    SUM(CASE
        WHEN p.id_selecao_mandante  = s.id_selecao
         AND p.gols_mandante > p.gols_visitante  THEN 1
        WHEN p.id_selecao_visitante = s.id_selecao
         AND p.gols_visitante > p.gols_mandante  THEN 1
        ELSE 0 END)                                                 AS vitorias
FROM TB_PARTIDA p
INNER JOIN TB_SELECAO s
    ON s.id_selecao IN (p.id_selecao_mandante, p.id_selecao_visitante)
INNER JOIN TB_FASE f ON f.id_fase = p.id_fase
WHERE f.descricao IN (
    'Group 1', 'Group 2', 'Group 3', 'Group 4',
    'Group 5', 'Group 6',
    'Group A', 'Group B', 'Group C', 'Group D',
    'Group E', 'Group F', 'Group G', 'Group H',
    'First round', 'Preliminary round'
)
GROUP BY s.id_selecao
HAVING jogos_na_fase_de_grupos >= 6
ORDER BY vitorias DESC
LIMIT 10;
