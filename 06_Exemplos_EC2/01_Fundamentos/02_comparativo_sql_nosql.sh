#!/usr/bin/env bash
# =============================================================================
# Comparativo entre bancos SQL (relacionais) e NoSQL (não relacionais)
#
# Este script cria dados de exemplo e simula como cada abordagem
# lidaria com consultas. Não instala nada — apenas demonstra conceitos.
#
# Uso: chmod +x 02_comparativo_sql_nosql.sh && ./02_comparativo_sql_nosql.sh
# =============================================================================

set -e

echo "================================================================"
echo "  COMPARATIVO: SQL vs NoSQL"
echo "================================================================"
echo ""

sleep 1

# ------------------------------------------------------------------
# 1. CRIAR ARQUIVO CSV COM DADOS DE EXEMPLO
# ------------------------------------------------------------------
echo ">>> Criando dados de exemplo (clientes e pedidos)..."
echo ""

cat > dados.csv << CSV
id_cliente;nome;cidade;id_pedido;produto;valor
1;Ana Silva;São Paulo;101;Notebook;4500.00
1;Ana Silva;São Paulo;102;Mouse;150.00
2;Carlos Lima;Rio de Janeiro;103;Teclado;200.00
3;Marina Dias;Belo Horizonte;104;Monitor;1200.00
3;Marina Dias;Belo Horizonte;105;Webcam;300.00
CSV

echo "Conteúdo do arquivo dados.csv:"
echo "id_cliente;nome;cidade;id_pedido;produto;valor"
cat dados.csv
echo ""

sleep 2

# ------------------------------------------------------------------
# 2. ABORDAGEM SQL (relacional)
# ------------------------------------------------------------------
echo "================================================================"
echo "  ABORDAGEM SQL (Relacional)"
echo "================================================================"
echo ""
sleep 1

echo "No SQL, os dados seriam normalizados em tabelas separadas:"
echo ""
echo "  CREATE TABLE clientes ("
echo "      id_cliente INT PRIMARY KEY,"
echo "      nome VARCHAR(100),"
echo "      cidade VARCHAR(50)"
echo "  );"
echo ""
echo "  CREATE TABLE pedidos ("
echo "      id_pedido INT PRIMARY KEY,"
echo "      id_cliente INT REFERENCES clientes(id_cliente),"
echo "      produto VARCHAR(100),"
echo "      valor DECIMAL(10,2)"
echo "  );"
echo ""
sleep 2

echo "Consulta SQL (simulada):"
echo ""
echo "  SELECT c.nome, c.cidade, p.produto, p.valor"
echo "  FROM clientes c"
echo "  JOIN pedidos p ON c.id_cliente = p.id_cliente"
echo "  WHERE c.cidade = 'São Paulo';"
echo ""

# Simula o resultado do JOIN
echo "Resultado da consulta SQL:"
echo ""
printf "  %-20s %-20s %-15s %s\n" "nome" "cidade" "produto" "valor"
echo "  ------------------------------------------------------------------"
printf "  %-20s %-20s %-15s %s\n" "Ana Silva" "São Paulo" "Notebook" "R$ 4.500,00"
printf "  %-20s %-20s %-15s %s\n" "Ana Silva" "São Paulo" "Mouse" "R$ 150,00"
echo ""

sleep 2

echo "Características da abordagem SQL:"
echo "  - Esquema rígido (schema-on-write)"
echo "  - Dados normalizados (evita redundância)"
echo "  - JOINs para combinar dados de tabelas diferentes"
echo "  - Garantia ACID (Atomicidade, Consistência, Isolamento, Durabilidade)"
echo "  - Escalabilidade vertical (mais CPU/RAM no mesmo servidor)"
echo ""

sleep 2

# ------------------------------------------------------------------
# 3. ABORDAGEM NoSQL (documentos)
# ------------------------------------------------------------------
echo "================================================================"
echo "  ABORDAGEM NoSQL — Documentos (MongoDB)"
echo "================================================================"
echo ""
sleep 1

echo "No MongoDB, os mesmos dados seriam armazenados como documentos"
echo "embutidos (embedded), sem necessidade de JOIN:"
echo ""
echo "  db.clientes.insertOne({"
echo "    id_cliente: 1,"
echo "    nome: 'Ana Silva',"
echo "    cidade: 'São Paulo',"
echo "    pedidos: ["
echo "      { id_pedido: 101, produto: 'Notebook', valor: 4500.00 },"
echo "      { id_pedido: 102, produto: 'Mouse', valor: 150.00 }"
echo "    ]"
echo "  });"
echo ""

sleep 2

echo "Consulta NoSQL (simulada):"
echo ""
echo "  db.clientes.find("
echo "    { cidade: 'São Paulo' },"
echo "    { nome: 1, cidade: 1, pedidos: 1 }"
echo "  );"
echo ""

echo "Resultado da consulta NoSQL:"
echo ""
echo "  {"
echo "    id_cliente: 1,"
echo "    nome: 'Ana Silva',"
echo "    cidade: 'São Paulo',"
echo "    pedidos: ["
echo "      { produto: 'Notebook', valor: 4500.00 },"
echo "      { produto: 'Mouse', valor: 150.00 }"
echo "    ]"
echo "  }"
echo ""

sleep 2

echo "Características da abordagem NoSQL:"
echo "  - Esquema flexível (schema-on-read)"
echo "  - Dados desnormalizados (redundância controlada)"
echo "  - Sem JOINs (dados embutidos ou referenciados)"
echo "  - BASE (Basically Available, Soft state, Eventual consistency)"
echo "  - Escalabilidade horizontal (sharding/distribuição)"
echo ""

sleep 2

# ------------------------------------------------------------------
# 4. COMPARAÇÃO DIRETA
# ------------------------------------------------------------------
echo "================================================================"
echo "  COMPARAÇÃO DIRETA: SQL vs NoSQL"
echo "================================================================"
echo ""

cat << COMPARACAO
  +-----------------------------+--------------------------+--------------------------+
  | Critério                    | SQL                      | NoSQL                    |
  +-----------------------------+--------------------------+--------------------------+
  | Modelo de dados             | Tabelas (linhas/colunas) | Documentos, grafos, etc. |
  | Esquema                     | Fixo (schema-on-write)   | Flexível (schema-on-read)|
  | Linguagem de consulta       | SQL (padronizado)        | Variável (cada banco)    |
  | Propriedades                | ACID                     | BASE                     |
  | Relacionamentos             | JOINs (foreign keys)     | Embutidos ou referências |
  | Escalabilidade              | Vertical                 | Horizontal               |
  | Consistência                | Forte (imediata)         | Eventual (eventual)      |
  | Exemplos                    | PostgreSQL, MySQL        | MongoDB, Cassandra, Redis|
  | Melhor para                 | Dados estruturados,      | Big data, alta disponibi-|
  |                             | transações bancárias     | lidade, dados não-estrut.|
  +-----------------------------+--------------------------+--------------------------+

COMPARACAO

sleep 3

echo ""
echo "================================================================"
echo "  CONCLUSÃO"
echo "================================================================"
echo ""
echo "SQL e NoSQL não são concorrentes — são ferramentas diferentes"
echo "para problemas diferentes. Muitos sistemas modernos usam ambos"
echo "(abordagem poliglota):"
echo ""
echo "  - SQL para transações financeiras e relatórios"
echo "  - MongoDB para catálogo de produtos e sessões de usuário"
echo "  - Redis para cache e filas"
echo "  - Cassandra para logs e séries temporais"
echo ""
echo "Fim da demonstração."
echo ""

# Limpa o arquivo temporário
rm -f dados.csv
