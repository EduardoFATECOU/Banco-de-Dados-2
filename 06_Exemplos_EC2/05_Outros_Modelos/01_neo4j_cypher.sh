#!/usr/bin/env bash
# =============================================================================
# Exemplo de uso do Neo4j com Cypher (via Docker)
#
# Neo4j é um banco de dados orientado a grafos. Dados são armazenados como
# nós (nodes) e relacionamentos (relationships), permitindo consultas
# complexas de conectividade.
#
# Uso: chmod +x 01_neo4j_cypher.sh && ./01_neo4j_cypher.sh
# Requer: Docker instalado
# =============================================================================

set -e

echo "================================================================"
echo "  NEO4J — Banco de Dados em Grafo (Cypher)"
echo "================================================================"
echo ""

NEO4J_CONTAINER="neo4j_banco2"
NEO4J_PORT=7474
BOLT_PORT=7687
NEO4J_PASSWORD="senha123"

# ------------------------------------------------------------------
# 1. Verifica se o container já existe
# ------------------------------------------------------------------
echo ">>> Verificando container Neo4j..."

if docker ps --format '{{.Names}}' | grep -q "^$NEO4J_CONTAINER$"; then
    echo "    Container '$NEO4J_CONTAINER' já está rodando."
elif docker ps -a --format '{{.Names}}' | grep -q "^$NEO4J_CONTAINER$"; then
    echo "    Container '$NEO4J_CONTAINER' existe mas está parado. Iniciando..."
    docker start "$NEO4J_CONTAINER"
else
    echo "    Criando container Neo4j..."
    docker run -d \
        --name "$NEO4J_CONTAINER" \
        -p $NEO4J_PORT:7474 \
        -p $BOLT_PORT:7687 \
        -e NEO4J_AUTH=neo4j/$NEO4J_PASSWORD \
        -e NEO4J_PLUGINS='["apoc"]' \
        neo4j:5-community
fi

echo ""
echo "    Neo4j disponível em:"
echo "      - Interface web: http://localhost:$NEO4J_PORT"
echo "      - Bolt:          localhost:$BOLT_PORT"
echo "      - Usuário:       neo4j"
echo "      - Senha:         $NEO4J_PASSWORD"
echo ""

sleep 3

# ------------------------------------------------------------------
# 2. Função para executar Cypher via curl
# ------------------------------------------------------------------
executar_cypher() {
    local cypher=$1
    local descricao=$2

    echo ">>> $descricao"

    # Codifica a query para JSON
    curl -s -X POST \
        "http://localhost:$NEO4J_PORT/db/neo4j/tx/commit" \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic $(echo -n "neo4j:$NEO4J_PASSWORD" | base64 -w 0)" \
        -d "{\"statements\":[{\"statement\":\"$cypher\"}]}" \
        | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'    {r[\"row\"]}') for r in d.get('results',[{}])[0].get('data',[])]" 2>/dev/null || echo "    (executado)"

    echo ""
    sleep 1
}

# ------------------------------------------------------------------
# 3. Criar nós e relacionamentos (rede social simples)
# ------------------------------------------------------------------
echo "================================================================"
echo "  CRIANDO GRAFO: Rede Social"
echo "  Nós: Pessoa | Relacionamento: CONHECE"
echo "================================================================"
echo ""

# Cria pessoas (nós)
executar_cypher \
    "CREATE (a:Pessoa {nome: 'Ana', idade: 28, cidade: 'São Paulo'})" \
    "Criando pessoa: Ana"

executar_cypher \
    "CREATE (b:Pessoa {nome: 'Carlos', idade: 32, cidade: 'Rio de Janeiro'})" \
    "Criando pessoa: Carlos"

executar_cypher \
    "CREATE (c:Pessoa {nome: 'Marina', idade: 25, cidade: 'Belo Horizonte'})" \
    "Criando pessoa: Marina"

executar_cypher \
    "CREATE (d:Pessoa {nome: 'Rafael', idade: 30, cidade: 'São Paulo'})" \
    "Criando pessoa: Rafael"

executar_cypher \
    "CREATE (e:Pessoa {nome: 'Juliana', idade: 27, cidade: 'Campinas'})" \
    "Criando pessoa: Juliana"

echo ">>> Pessoas criadas. Agora criando relacionamentos..."

# Cria relacionamentos de amizade (arestas)
executar_cypher \
    "MATCH (a:Pessoa {nome: 'Ana'}), (b:Pessoa {nome: 'Carlos'}) CREATE (a)-[:CONHECE {desde: 2020}]->(b)" \
    "Ana -> CONHECE -> Carlos"

executar_cypher \
    "MATCH (a:Pessoa {nome: 'Ana'}), (c:Pessoa {nome: 'Marina'}) CREATE (a)-[:CONHECE {desde: 2022}]->(c)" \
    "Ana -> CONHECE -> Marina"

executar_cypher \
    "MATCH (b:Pessoa {nome: 'Carlos'}), (c:Pessoa {nome: 'Marina'}) CREATE (b)-[:CONHECE {desde: 2021}]->(c)" \
    "Carlos -> CONHECE -> Marina"

executar_cypher \
    "MATCH (a:Pessoa {nome: 'Ana'}), (d:Pessoa {nome: 'Rafael'}) CREATE (a)-[:CONHECE {desde: 2019}]->(d)" \
    "Ana -> CONHECE -> Rafael"

executar_cypher \
    "MATCH (d:Pessoa {nome: 'Rafael'}), (e:Pessoa {nome: 'Juliana'}) CREATE (d)-[:CONHECE {desde: 2023}]->(e)" \
    "Rafael -> CONHECE -> Juliana"

executar_cypher \
    "MATCH (c:Pessoa {nome: 'Marina'}), (e:Pessoa {nome: 'Juliana'}) CREATE (c)-[:CONHECE {desde: 2023}]->(e)" \
    "Marina -> CONHECE -> Juliana"

echo "================================================================"
echo "  CONSULTAS NO GRAFO"
echo "================================================================"
echo ""

# 4. Consultas
executar_cypher \
    "MATCH (p:Pessoa) RETURN p.nome AS nome, p.idade AS idade, p.cidade AS cidade ORDER BY p.nome" \
    "Listar todas as pessoas"

executar_cypher \
    "MATCH (a:Pessoa {nome: 'Ana'})-[:CONHECE]->(amigo:Pessoa) RETURN amigo.nome AS amigo, amigo.cidade AS cidade" \
    "Quem Ana conhece?"

executar_cypher \
    "MATCH (a:Pessoa {nome: 'Ana'})-[:CONHECE*2]-(conhecido:Pessoa) RETURN DISTINCT conhecido.nome AS conhecido_indireto" \
    "Amigos de amigos de Ana (2 níveis)"

executar_cypher \
    "MATCH (p:Pessoa)-[:CONHECE]->(amigo:Pessoa) RETURN p.nome AS pessoa, COUNT(amigo) AS amigos ORDER BY amigos DESC" \
    "Ranking: quem tem mais amigos?"

executar_cypher \
    "MATCH path = shortestPath((a:Pessoa {nome: 'Ana'})-[:CONHECE*]-(e:Pessoa {nome: 'Juliana'})) RETURN [n IN nodes(path) | n.nome] AS caminho" \
    "Menor caminho entre Ana e Juliana"

sleep 1

echo "================================================================"
echo "  EXPLICAÇÃO"
echo "================================================================"
echo ""
echo "Neo4j armazena dados como GRAFO, composto por:"
echo ""
echo "  - NÓS (Nodes): entidades (Pessoa, Produto, Local, ...)"
echo "  - RELACIONAMENTOS (Relationships): conexões (CONHECE, COMPROU, ...)"
echo "  - PROPRIEDADES: atributos (nome, idade, cidade, ...)"
echo "  - RÓTULOS (Labels): categorias (:Pessoa, :Produto)"
echo ""
echo "Cypher é a linguagem de consulta do Neo4j:"
echo ""
echo "  CREATE  - Cria nós e relacionamentos"
echo "  MATCH   - Encontra padrões no grafo"
echo "  RETURN  - Retorna dados"
echo "  WHERE   - Filtra resultados"
echo "  DELETE  - Remove nós/relacionamentos"
echo ""
echo "Vantagens dos bancos de grafo:"
echo "  - Consultas de conectividade (amigos em comum, menor caminho)"
echo "  - Relacionamentos complexos e mutáveis"
echo "  - Performance constante mesmo com muitos níveis de profundidade"
echo ""

# Para acessar a interface web, informe as credenciais
echo "Para acessar a interface web do Neo4j:"
echo "  URL:    http://localhost:$NEO4J_PORT"
echo "  Usuário: neo4j"
echo "  Senha:   $NEO4J_PASSWORD"
echo ""

echo "Para parar o container quando terminar:"
echo "  docker stop $NEO4J_CONTAINER"
echo ""
echo "Demonstração Neo4j concluída!"
