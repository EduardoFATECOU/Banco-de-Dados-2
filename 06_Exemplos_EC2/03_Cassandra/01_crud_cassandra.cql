-- =============================================================================
-- Exemplo de operações CRUD no Apache Cassandra usando CQL
-- Keyspace: loja | Tabela: produtos
--
-- Diferente do SQL tradicional, o Cassandra usa CQL (Cassandra Query Language)
-- e é orientado a consultas — o modelo de dados é definido pelos padrões
-- de acesso (queries primeiro, tabelas depois).
--
-- Uso: cat 01_crud_cassandra.cql | cqlsh
-- Requer: cqlsh instalado e Cassandra rodando
-- =============================================================================

-- ==========================================================================
-- 1. CREATE KEYSPACE — Criar o keyspace (equivalente a um "database")
-- ==========================================================================

-- O keyspace define o fator de replicação e a estratégia de replicação.
-- SimpleStrategy é usado para desenvolvimento local (um datacenter).
CREATE KEYSPACE IF NOT EXISTS loja
WITH replication = {
    'class': 'SimpleStrategy',
    'replication_factor': 1
};

-- Usa o keyspace recém-criado
USE loja;

-- ==========================================================================
-- 2. CREATE TABLE — Criar a tabela "produtos"
-- ==========================================================================

-- No Cassandra, a chave primária é dividida em:
--   - Partition key (primeira parte): define em qual nó os dados ficam
--   - Clustering columns (demais): definem a ordem dentro da partição
--
-- UUID como partition key distribui os dados uniformemente.
CREATE TABLE IF NOT EXISTS produtos (
    id UUID,            -- Identificador único (partition key)
    nome text,          -- Nome do produto
    preco decimal,      -- Preço (decimal para precisão financeira)
    categoria text,     -- Categoria do produto
    estoque int,        -- Quantidade em estoque
    PRIMARY KEY (id)
);

-- ==========================================================================
-- 3. INSERT — Inserir documentos (registros)
-- ==========================================================================

-- Insere 6 produtos no catálogo.
-- UUID é gerado automaticamente com uuid() ou informado manualmente.
INSERT INTO produtos (id, nome, preco, categoria, estoque)
VALUES (123e4567-e89b-12d3-a456-426614174000, 'Notebook Dell', 4500.00, 'Informatica', 10);

INSERT INTO produtos (id, nome, preco, categoria, estoque)
VALUES (uuid(), 'Mouse Sem Fio', 150.00, 'Informática', 50);

INSERT INTO produtos (id, nome, preco, categoria, estoque)
VALUES (uuid(), 'Teclado Mecânico', 350.00, 'Informática', 30);

INSERT INTO produtos (id, nome, preco, categoria, estoque)
VALUES (uuid(), 'Monitor 27"', 1800.00, 'Informática', 15);

INSERT INTO produtos (id, nome, preco, categoria, estoque)
VALUES (uuid(), 'Cadeira Ergonômica', 2200.00, 'Móveis', 8);

INSERT INTO produtos (id, nome, preco, categoria, estoque)
VALUES (uuid(), 'Mesa Digitalizadora', 800.00, 'Informática', 20);

-- ==========================================================================
-- 4. SELECT — Consultar dados
-- ==========================================================================

-- 4.1 Listar todos os produtos
-- ATENÇÃO: SELECT * sem WHERE é permitido mas NÃO recomendado em produção,
-- pois pode sobrecarregar o cluster. Use ALLOW FILTERING com cuidado.
CONSISTENCY ONE;
SELECT * FROM produtos;

-- 4.2 Consultar por ID (consulta eficiente pois usa a partition key)
-- Substitua o UUID pelo valor retornado no SELECT acima
-- SELECT * FROM produtos WHERE id = <uuid-aqui>;

-- 4.3 Contar registros
SELECT COUNT(*) FROM produtos;

-- 4.4 Filtrar por categoria (precisa de ALLOW FILTERING porque categoria
-- não é chave primária — isso é ineficiente em produção)
SELECT nome, preco, estoque FROM produtos
WHERE categoria = 'Informática'
ALLOW FILTERING;

-- ==========================================================================
-- 5. UPDATE — Atualizar dados
-- ==========================================================================

-- Atualiza o preço de um produto. No Cassandra, UPDATE e INSERT são
-- equivalentes (upsert) — se o registro não existir, ele é criado.
UPDATE produtos
SET preco = 4800.00, estoque = 12
WHERE id = 123e4567-e89b-12d3-a456-426614174000
IF EXISTS;  -- Garante que só atualiza se existir

-- ATENÇÃO: UPDATE sempre exige a partition key completa (id).
-- -- UPDATE produtos SET preco = 4800.00 WHERE id = 123e4567-e89b-12d3-a456-426614174000;

-- ==========================================================================
-- 6. DELETE — Remover dados
-- ==========================================================================

-- Remove um produto pelo ID (substitua pelo UUID real)
-- DELETE FROM produtos WHERE id = <uuid>;

-- Remove todos os produtos de uma categoria (se necessário)
-- DELETE FROM produtos WHERE categoria = 'Móveis';  -- Não funciona sem partition key

-- ==========================================================================
-- 7. CONSULTAS ADICIONAIS
-- ==========================================================================

-- Produtos com estoque baixo (exemplo conceitual)
-- SELECT nome, estoque FROM produtos WHERE estoque < 10 ALLOW FILTERING;

-- ==========================================================================
-- 8. LIMPEZA (opcional — descomente para remover os dados)
-- ==========================================================================

-- Para remover a tabela e o keyspace ao final:
-- DROP TABLE IF EXISTS produtos;
-- DROP KEYSPACE IF EXISTS loja;

-- ==========================================================================
-- OBSERVAÇÕES IMPORTANTES
-- ==========================================================================
-- 1. Cassandra NÃO suporta JOINs, foreign keys ou subqueries.
-- 2. O modelo de dados deve ser orientado a consultas (query-first).
-- 3. ALLOW FILTERING deve ser usado com moderação — idealmente,
--    crie tabelas específicas para cada padrão de consulta.
-- 4. A consistência é configurável: ONE, QUORUM, ALL, etc.
-- 5. O comando CONSISTENCY define o nível de consistência da sessão.
-- ==========================================================================
