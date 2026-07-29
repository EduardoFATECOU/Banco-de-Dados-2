#!/usr/bin/env bash
# =============================================================================
# Demonstracao de modelagem orientada a consultas no Apache Cassandra
#
# No Cassandra, a modelagem e diferente do SQL relacional:
#  1. Identifique as consultas que o sistema precisa responder
#  2. Crie uma tabela para cada consulta
#  3. Insira dados denormalizados (redundancia controlada)
#
# Keyspace: biblioteca | Tabelas: livros_por_autor, livros_por_ano, livros_por_categoria
#
# Uso: chmod +x 02_modelagem_cql.sh && ./02_modelagem_cql.sh
# Requer: cqlsh instalado e Cassandra rodando
# =============================================================================

echo "================================================================"
echo "  CASSANDRA - Modelagem Orientada a Consultas (Query-First)"
echo "  Keyspace: biblioteca"
echo "================================================================"
echo ""

echo "No Cassandra, modelamos os dados com base nas consultas que"
echo "precisamos responder. Cada tabela e otimizada para uma consulta"
echo "especifica, mesmo que isso signifique duplicar dados."
echo ""

sleep 2

echo "Consultas que nosso sistema precisa atender:"
echo ""
echo "  1. Quais livros de um determinado autor?"
echo "  2. Quais livros publicados em um determinado ano?"
echo "  3. Quais livros de uma determinada categoria?"
echo ""
echo "No SQL relacional, usariamos uma tabela 'livros' com indices."
echo "No Cassandra, criamos 3 tabelas, uma para cada consulta."
echo ""

sleep 2

echo ">>> Criando keyspace biblioteca..."
cqlsh << 'EOF'
CREATE KEYSPACE IF NOT EXISTS biblioteca
WITH replication = {
    'class': 'SimpleStrategy',
    'replication_factor': 1
};
EOF

echo ">>> Criando tabela livros_por_autor..."
cqlsh << 'EOF'
USE biblioteca;
CREATE TABLE IF NOT EXISTS livros_por_autor (
    autor text,
    ano_publicacao int,
    titulo text,
    editora text,
    isbn text,
    PRIMARY KEY (autor, ano_publicacao, titulo)
) WITH CLUSTERING ORDER BY (ano_publicacao DESC, titulo ASC);
EOF

echo ">>> Criando tabela livros_por_ano..."
cqlsh << 'EOF'
USE biblioteca;
CREATE TABLE IF NOT EXISTS livros_por_ano (
    ano_publicacao int,
    autor text,
    titulo text,
    editora text,
    isbn text,
    PRIMARY KEY (ano_publicacao, autor, titulo)
) WITH CLUSTERING ORDER BY (autor ASC, titulo ASC);
EOF

echo ">>> Criando tabela livros_por_categoria..."
cqlsh << 'EOF'
USE biblioteca;
CREATE TABLE IF NOT EXISTS livros_por_categoria (
    categoria text,
    titulo text,
    autor text,
    ano_publicacao int,
    editora text,
    isbn text,
    PRIMARY KEY (categoria, titulo, autor)
);
EOF

echo ">>> Inserindo dados nas 3 tabelas..."
cqlsh << 'EOF'
USE biblioteca;
INSERT INTO livros_por_autor (autor, ano_publicacao, titulo, editora, isbn)
VALUES ('George Orwell', 1949, '1984', 'Companhia das Letras', '978-8535909557');
INSERT INTO livros_por_ano (ano_publicacao, autor, titulo, editora, isbn)
VALUES (1949, 'George Orwell', '1984', 'Companhia das Letras', '978-8535909557');
INSERT INTO livros_por_categoria (categoria, titulo, autor, ano_publicacao, editora, isbn)
VALUES ('Ficcao Cientifica', '1984', 'George Orwell', 1949, 'Companhia das Letras', '978-8535909557');

INSERT INTO livros_por_autor (autor, ano_publicacao, titulo, editora, isbn)
VALUES ('George Orwell', 1945, 'A Revolucao dos Bichos', 'Companhia das Letras', '978-8535909558');
INSERT INTO livros_por_ano (ano_publicacao, autor, titulo, editora, isbn)
VALUES (1945, 'George Orwell', 'A Revolucao dos Bichos', 'Companhia das Letras', '978-8535909558');
INSERT INTO livros_por_categoria (categoria, titulo, autor, ano_publicacao, editora, isbn)
VALUES ('Fabula', 'A Revolucao dos Bichos', 'George Orwell', 1945, 'Companhia das Letras', '978-8535909558');

INSERT INTO livros_por_autor (autor, ano_publicacao, titulo, editora, isbn)
VALUES ('J.R.R. Tolkien', 1954, 'O Senhor dos Aneis', 'Martins Fontes', '978-8533613379');
INSERT INTO livros_por_ano (ano_publicacao, autor, titulo, editora, isbn)
VALUES (1954, 'J.R.R. Tolkien', 'O Senhor dos Aneis', 'Martins Fontes', '978-8533613379');
INSERT INTO livros_por_categoria (categoria, titulo, autor, ano_publicacao, editora, isbn)
VALUES ('Fantasia', 'O Senhor dos Aneis', 'J.R.R. Tolkien', 1954, 'Martins Fontes', '978-8533613379');

INSERT INTO livros_por_autor (autor, ano_publicacao, titulo, editora, isbn)
VALUES ('J.R.R. Tolkien', 1937, 'O Hobbit', 'Martins Fontes', '978-8533613386');
INSERT INTO livros_por_ano (ano_publicacao, autor, titulo, editora, isbn)
VALUES (1937, 'J.R.R. Tolkien', 'O Hobbit', 'Martins Fontes', '978-8533613386');
INSERT INTO livros_por_categoria (categoria, titulo, autor, ano_publicacao, editora, isbn)
VALUES ('Fantasia', 'O Hobbit', 'J.R.R. Tolkien', 1937, 'Martins Fontes', '978-8533613386');

INSERT INTO livros_por_autor (autor, ano_publicacao, titulo, editora, isbn)
VALUES ('Isaac Asimov', 1951, 'Fundacao', 'Aleph', '978-8576572055');
INSERT INTO livros_por_ano (ano_publicacao, autor, titulo, editora, isbn)
VALUES (1951, 'Isaac Asimov', 'Fundacao', 'Aleph', '978-8576572055');
INSERT INTO livros_por_categoria (categoria, titulo, autor, ano_publicacao, editora, isbn)
VALUES ('Ficcao Cientifica', 'Fundacao', 'Isaac Asimov', 1951, 'Aleph', '978-8576572055');
EOF

echo ">>> Dados inseridos com sucesso!"
echo ""

echo "=============================================================="
echo "  CONSULTA 1: Livros de George Orwell"
echo "  Tabela: livros_por_autor (partition key: autor)"
echo "=============================================================="
cqlsh << 'EOF'
USE biblioteca;
SELECT titulo, ano_publicacao, editora
FROM livros_por_autor
WHERE autor = 'George Orwell';
EOF

echo ""

echo "=============================================================="
echo "  CONSULTA 2: Livros publicados em 1954"
echo "  Tabela: livros_por_ano (partition key: ano_publicacao)"
echo "=============================================================="
cqlsh << 'EOF'
USE biblioteca;
SELECT titulo, autor, editora
FROM livros_por_ano
WHERE ano_publicacao = 1954;
EOF

echo ""

echo "=============================================================="
echo "  CONSULTA 3: Livros de Fantasia"
echo "  Tabela: livros_por_categoria (partition key: categoria)"
echo "=============================================================="
cqlsh << 'EOF'
USE biblioteca;
SELECT titulo, autor, ano_publicacao
FROM livros_por_categoria
WHERE categoria = 'Fantasia';
EOF

echo ""
echo "=============================================================="
echo "  POR QUE 3 TABELAS?"
echo "=============================================================="
echo ""
echo "No Cassandra, NAO usamos JOINs ou indices secundarios"
echo "para consultas frequentes. Cada tabela e modelada para"
echo "responder UMA consulta especifica com performance maxima."
echo ""
echo "Vantagens desta abordagem:"
echo "  - Consultas sempre usam a partition key (eficientes)"
echo "  - Dados ja vem ordenados conforme necessario"
echo "  - Sem necessidade de JOINs ou indices secundarios"
echo ""
echo "Desvantagens:"
echo "  - Redundancia de dados (mesmo dado em varias tabelas)"
echo "  - Mais espaco em disco"
echo "  - Aplicacao precisa manter dados consistentes"
echo "=============================================================="

echo ""
echo "Script de modelagem concluido."