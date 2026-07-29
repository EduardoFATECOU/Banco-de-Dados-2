#!/usr/bin/env bash
# =============================================================================
# Exemplo de Persistência Poliglota
#
# Persistência Poliglota (Polyglot Persistence) é o conceito de usar
# diferentes bancos de dados NoSQL para diferentes necessidades dentro
# de uma mesma aplicação, aproveitando o melhor de cada modelo.
#
# Uso: chmod +x 09_poliglota.sh && ./09_poliglota.sh
# Requer: MongoDB, Redis e Cassandra rodando (docker ou local)
# =============================================================================

set -e

echo "================================================================"
echo "  PERSISTÊNCIA POLIGLOTA — Múltiplos Bancos, Uma Aplicação"
echo "================================================================"
echo ""

echo "Em vez de usar um único banco relacional para tudo, a"
echo "persistência poliglota escolhe o banco ideal para cada"
echo "tipo de dado e operação:"
echo ""

# ------------------------------------------------------------------
# 1. MongoDB — Dados documentais (catálogo de produtos)
# ------------------------------------------------------------------
echo "=============================================================="
echo "  1. MONGODB — Dados Documentais (Catálogo de Produtos)"
echo "=============================================================="
echo ""
echo "  MongoDB é ideal para dados semi-estruturados que podem"
echo "  variar de produto para produto (schema flexível)."
echo "  Produtos diferentes têm atributos diferentes:"
echo ""
echo "  {"
echo "    \"nome\": \"Smartphone XYZ\","
echo "    \"preco\": 2499.00,"
echo "    \"especificacoes\": {"
echo "      \"tela\": \"6.5 pol\","
echo "      \"ram\": \"8GB\","
echo "      \"cor\": \"Preto\""
echo "    }"
echo "  }"
echo ""
echo "  Vantagem: schema flexível, consultas ricas por atributo"
echo ""

# Verifica se MongoDB está acessível
if mongosh --quiet --eval "db.runCommand({ping:1})" 2>/dev/null; then
    mongosh --quiet --eval '
        db = db.getSiblingDB("ecommerce");
        db.produtos.insertMany([
            { nome: "Smartphone XYZ", preco: 2499, categoria: "eletronicos", specs: { tela: "6.5 pol", ram: "8GB" } },
            { nome: "Camiseta Algodão", preco: 79.90, categoria: "roupas", specs: { tamanho: "M", cor: "Azul" } }
        ]);
        print("    Produtos inseridos no MongoDB com sucesso!");
        print("    Total: " + db.produtos.countDocuments() + " documentos");
    '
else
    echo "    (MongoDB não disponível — ignore esta etapa)"
fi
echo ""

# ------------------------------------------------------------------
# 2. Redis — Cache de alta performance
# ------------------------------------------------------------------
echo "=============================================================="
echo "  2. REDIS — Cache de Alta Performance"
echo "=============================================================="
echo ""
echo "  Redis armazena dados em memória para acesso ultra-rápido."
echo "  Usado para cache de consultas frequentes e sessões:"
echo ""
echo "  > cache:produto:1 = '{\"nome\":\"Smartphone XYZ\",...}'"
echo "  > cache:produto:2 = '{\"nome\":\"Camiseta Algodão\",...}'"
echo ""
echo "  Vantagem: latência sub-milissegundo (vs ms do MongoDB)"
echo ""

if redis-cli PING 2>/dev/null | grep -q PONG; then
    redis-cli SET "cache:produto:1" '{"nome":"Smartphone XYZ","preco":2499}' EX 60
    redis-cli SET "cache:produto:2" '{"nome":"Camiseta Algodão","preco":79.90}' EX 60
    echo "    Produtos armazenados em cache (TTL: 60s)"
    echo "    Tempo de acesso ao cache: ~$( (time redis-cli GET "cache:produto:1") 2>&1 | grep real || echo "0.1" )ms"
else
    echo "    (Redis não disponível — ignore esta etapa)"
fi
echo ""

# ------------------------------------------------------------------
# 3. Cassandra — Logs e séries temporais
# ------------------------------------------------------------------
echo "=============================================================="
echo "  3. CASSANDRA — Logs e Auditoria (Escrita Pesada)"
echo "=============================================================="
echo ""
echo "  Cassandra é otimizado para escrita intensa e escalabilidade"
echo "  horizontal. Ideal para logs de acesso e auditoria:"
echo ""
echo "  CREATE TABLE logs_acesso ("
echo "    produto_id UUID,"
echo "    timestamp TIMESTAMP,"
echo "    acao TEXT,"
echo "    ip TEXT,"
echo "    PRIMARY KEY (produto_id, timestamp)"
echo "  );"
echo ""
echo "  Vantagem: escrita horizontal, sem ponto único de falha"
echo ""

if cqlsh -e "SELECT release_version FROM system.local" 2>/dev/null; then
    cqlsh -e "
        CREATE KEYSPACE IF NOT EXISTS ecommerce
        WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};
        USE ecommerce;
        CREATE TABLE IF NOT EXISTS logs_acesso (
            produto_id UUID,
            timestamp TIMESTAMP,
            acao TEXT,
            ip TEXT,
            PRIMARY KEY (produto_id, timestamp)
        );
        INSERT INTO logs_acesso (produto_id, timestamp, acao, ip)
        VALUES (uuid(), toTimestamp(now()), 'visualizacao', '192.168.1.100');
        INSERT INTO logs_acesso (produto_id, timestamp, acao, ip)
        VALUES (uuid(), toTimestamp(now()), 'compra', '192.168.1.100');
    "
    echo "    Logs de auditoria inseridos no Cassandra"
else
    echo "    (Cassandra não disponível — ignore esta etapa)"
fi
echo ""

# ------------------------------------------------------------------
# 4. Neo4j — Recomendações (grafo)
# ------------------------------------------------------------------
echo "=============================================================="
echo "  4. NEO4J — Grafo de Recomendações"
echo "=============================================================="
echo ""
echo "  Bancos de grafo (Neo4j) são ideais para relações complexas"
echo "  como 'clientes que compraram X também compraram Y':"
echo ""
echo "  (Cliente:João)-[:COMPROU]->(Produto:Smartphone)"
echo "  (Cliente:Maria)-[:COMPROU]->(Produto:Smartphone)"
echo "  (Cliente:Maria)-[:COMPROU]->(Produto:Fone)"
echo "  => Recomendar Fone para João"
echo ""
echo "  Vantagem: consultas de relacionamento profundas (joins"
echo "  complexos em SQL vs navegação natural em grafo)"
echo ""
echo ""

# ------------------------------------------------------------------
# 5. Resumo / Comparação
# ------------------------------------------------------------------
echo "=============================================================="
echo "  RESUMO — Por que Poliglota?"
echo "=============================================================="
echo ""
echo "  +------------------+----------------+----------------------+"
echo "  | Banco            | Melhor Para    | Evitar Quando        |"
echo "  +------------------+----------------+----------------------+"
echo "  | MongoDB          | Documentos     | Relacionamentos      |"
echo "  |                  | flexíveis      | complexos (joins)    |"
echo "  +------------------+----------------+----------------------+"
echo "  | Redis            | Cache, filas,  | Dados persistentes   |"
echo "  |                  | sessões        | (> RAM disponível)   |"
echo "  +------------------+----------------+----------------------+"
echo "  | Cassandra        | Escrita alta,  | Consultas ad-hoc,    |"
echo "  |                  | logs, IoT      | Joins, aggregations  |"
echo "  +------------------+----------------+----------------------+"
echo "  | Neo4j            | Grafos, redes  | Dados tabulares      |"
echo "  |                  | sociais        | simples              |"
echo "  +------------------+----------------+----------------------+"
echo "  | Elasticsearch    | Busca textual  | Transações ACID      |"
echo "  +------------------+----------------+----------------------+"
echo "  | InfluxDB         | Séries temp.   | Dados relacionais    |"
echo "  +------------------+----------------+----------------------+"
echo "  | MinIO/S3         | Objetos,       | Dados que precisam   |"
echo "  |                  | arquivos       | de consultas complexas|"
echo "  +------------------+----------------+----------------------+"
echo "  | Qdrant           | Busca vetorial | Dados exatos         |"
echo "  +------------------+----------------+----------------------+"
echo "  | PostGIS          | Dados espaciais| Dados não-geográficos|"
echo "  +------------------+----------------+----------------------+"
echo ""
echo "  Aplicação de e-commerce ideal (poliglota):"
echo "  - MongoDB:  Catálogo de produtos (docs flexíveis)"
echo "  - Redis:    Carrinho de compras, sessões (cache)"
echo "  - Cassandra:Histórico de pedidos, logs (escrita alta)"
echo "  - Neo4j:    Recomendações (grafo de relacionamentos)"
echo "  - MinIO:    Imagens dos produtos (objetos)"
echo "  - PostGIS:  Entregas, rotas (dados espaciais)"
echo "=============================================================="
echo ""

echo "Script Poliglota concluído."
