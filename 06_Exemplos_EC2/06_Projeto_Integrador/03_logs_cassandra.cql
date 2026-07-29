-- =============================================================================
-- Projeto Integrador — Logs de acesso no Cassandra
--
-- Armazena logs de consulta ao catálogo de filmes como séries temporais.
-- Cada acesso ao sistema gera um registro com timestamp, IP do usuário,
-- filme consultado e ação realizada.
--
-- Uso: cat 03_logs_cassandra.cql | cqlsh
-- Requer: cqlsh instalado e Cassandra rodando
-- =============================================================================

-- ==========================================================================
-- 1. CRIAR KEYSPACE
-- ==========================================================================
-- Usamos NetworkTopologyStrategy para simular um ambiente multi-datacenter.
-- SimpleStrategy é suficiente para ambiente local.
CREATE KEYSPACE IF NOT EXISTS cinema
WITH replication = {
    'class': 'SimpleStrategy',
    'replication_factor': 1
};

USE cinema;

-- ==========================================================================
-- 2. CRIAR TABELA DE LOGS
-- ==========================================================================
-- Modelagem orientada a consultas:
--   Consulta principal: "Quais logs de acesso para um determinado filme?"
--   Partition key: id_filme (para agrupar logs do mesmo filme)
--   Clustering key: timestamp (para ordenar por data/hora)
--
-- Se precisassemos consultar por IP ou por período, criaríamos tabelas
-- adicionais (ex: logs_por_ip, logs_por_data).
CREATE TABLE IF NOT EXISTS logs_acesso (
    id_filme int,           -- ID do filme no catalogo (partition key)
    timestamp timestamp,    -- Momento do acesso (clustering key)
    titulo text,            -- Titulo do filme (denormalizado)
    ip text,                -- Endereco IP do usuario
    acao text,              -- Tipo de acao: 'consulta', 'detalhe', 'compra'
    duracao_ms int,         -- Tempo de resposta em milissegundos
    PRIMARY KEY (id_filme, timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC);
-- Ordenacao DESC: logs mais recentes primeiro

-- ==========================================================================
-- 3. INSERIR DADOS DE EXEMPLO
-- ==========================================================================
-- Simula acessos ao catalogo de filmes.
-- id_filme referencia os documentos no MongoDB (1 a 20).
INSERT INTO logs_acesso (id_filme, timestamp, titulo, ip, acao, duracao_ms)
VALUES (1, '2025-07-20 10:30:00', 'Matrix', '192.168.1.100', 'consulta', 45);

INSERT INTO logs_acesso (id_filme, timestamp, titulo, ip, acao, duracao_ms)
VALUES (1, '2025-07-20 10:35:00', 'Matrix', '192.168.1.101', 'detalhe', 120);

INSERT INTO logs_acesso (id_filme, timestamp, titulo, ip, acao, duracao_ms)
VALUES (1, '2025-07-20 11:00:00', 'Matrix', '192.168.1.100', 'consulta', 2);
-- 2ms = estava em cache (Redis)

INSERT INTO logs_acesso (id_filme, timestamp, titulo, ip, acao, duracao_ms)
VALUES (3, '2025-07-20 11:15:00', 'Interestelar', '192.168.1.102', 'consulta', 48);

INSERT INTO logs_acesso (id_filme, timestamp, titulo, ip, acao, duracao_ms)
VALUES (3, '2025-07-20 11:20:00', 'Interestelar', '192.168.1.102', 'detalhe', 150);

INSERT INTO logs_acesso (id_filme, timestamp, titulo, ip, acao, duracao_ms)
VALUES (3, '2025-07-20 11:25:00', 'Interestelar', '192.168.1.103', 'consulta', 3);
-- 3ms = cache

INSERT INTO logs_acesso (id_filme, timestamp, titulo, ip, acao, duracao_ms)
VALUES (8, '2025-07-20 12:00:00', 'O Cavaleiro das Trevas', '192.168.1.100', 'consulta', 50);

INSERT INTO logs_acesso (id_filme, timestamp, titulo, ip, acao, duracao_ms)
VALUES (8, '2025-07-20 12:05:00', 'O Cavaleiro das Trevas', '192.168.1.104', 'consulta', 52);

INSERT INTO logs_acesso (id_filme, timestamp, titulo, ip, acao, duracao_ms)
VALUES (8, '2025-07-20 12:10:00', 'O Cavaleiro das Trevas', '192.168.1.104', 'compra', 800);

INSERT INTO logs_acesso (id_filme, timestamp, titulo, ip, acao, duracao_ms)
VALUES (15, '2025-07-20 14:00:00', 'Cidade de Deus', '192.168.1.105', 'consulta', 47);

INSERT INTO logs_acesso (id_filme, timestamp, titulo, ip, acao, duracao_ms)
VALUES (15, '2025-07-20 14:30:00', 'Cidade de Deus', '192.168.1.106', 'detalhe', 130);

INSERT INTO logs_acesso (id_filme, timestamp, titulo, ip, acao, duracao_ms)
VALUES (20, '2025-07-20 15:00:00', 'Whiplash', '192.168.1.107', 'consulta', 49);

INSERT INTO logs_acesso (id_filme, timestamp, titulo, ip, acao, duracao_ms)
VALUES (20, '2025-07-20 15:01:00', 'Whiplash', '192.168.1.107', 'detalhe', 140);

-- ==========================================================================
-- 4. CONSULTAS
-- ==========================================================================

-- 4.1 Logs de acesso ao filme "Matrix" (id_filme = 1)
--     Ordenados do mais recente para o mais antigo (clustering DESC)
SELECT id_filme, timestamp, titulo, ip, acao, duracao_ms
FROM logs_acesso
WHERE id_filme = 1;

-- 4.2 Logs do filme "Interestelar" (id_filme = 3)
SELECT id_filme, timestamp, titulo, ip, acao, duracao_ms
FROM logs_acesso
WHERE id_filme = 3;

-- 4.3 Logs do filme "O Cavaleiro das Trevas" (id_filme = 8)
SELECT id_filme, timestamp, titulo, ip, acao, duracao_ms
FROM logs_acesso
WHERE id_filme = 8;

-- 4.4 Contar acessos por filme
SELECT id_filme, titulo, COUNT(*) AS total_acessos
FROM logs_acesso
WHERE id_filme IN (1, 3, 8, 15, 20);

-- 4.5 Logs com tempo acima de 100ms (lentos)
-- ALLOW FILTERING necessario porque duracao_ms nao e chave primaria
SELECT id_filme, titulo, timestamp, duracao_ms
FROM logs_acesso
WHERE duracao_ms > 100
ALLOW FILTERING;

-- ==========================================================================
-- 5. CONSULTA AVANCADA: Distribuicao de acessos por hora
-- ==========================================================================
-- Podemos usar funcoes de agregacao do Cassandra (COUNT, SUM, AVG)
-- com a funcao de data/hora para agrupar por periodo.

-- Exemplo: acessos ao filme 1 por minuto
-- SELECT id_filme, timestamp, COUNT(*) AS acessos_por_minuto
-- FROM logs_acesso
-- WHERE id_filme = 1;

-- ==========================================================================
-- 6. LIMPEZA (opcional — descomente para remover os dados)
-- ==========================================================================
-- Para remover tabela e keyspace ao final:
-- DROP TABLE IF EXISTS logs_acesso;
-- DROP KEYSPACE IF EXISTS cinema;

-- ==========================================================================
-- OBSERVACOES
-- ==========================================================================
-- 1. Cassandra e excelente para series temporais (logs, metrics, eventos)
-- 2. A ordenacao por timestamp DESC permite buscar os logs mais recentes
--    rapidamente (sem necessidade de ORDER BY)
-- 3. Dados denormalizados (titulo) evitam JOIN com outro banco
-- 4. Para consultas por IP ou por periodo, crie tabelas adicionais
--    modeladas especificamente para essas consultas
-- ==========================================================================
