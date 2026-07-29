#!/usr/bin/env bash
# =============================================================================
# Exemplo de uso do Elasticsearch (via Docker)
#
# Elasticsearch é um mecanismo de busca e análise distribuído, baseado no
# Apache Lucene. Ideal para busca textual, logs e análise de dados.
#
# Uso: chmod +x 02_elasticsearch.sh && ./02_elasticsearch.sh
# Requer: Docker e curl instalados
# =============================================================================

set -e
echo "=== Liberando espaco em disco ==="
apt-get clean -qq 2>/dev/null || true
docker system prune -a -f 2>/dev/null || true
echo "=== Espaco apos limpeza ==="
df -h / | tail -1


echo "================================================================"
echo "  ELASTICSEARCH — Busca e Análise"
echo "================================================================"
echo ""

ES_CONTAINER="elasticsearch_banco2"
ES_PORT=9200
ES_PASSWORD="elastic123"
ES_VERSION="8.12.0"

# ------------------------------------------------------------------
# 1. Iniciar Elasticsearch no Docker
# ------------------------------------------------------------------
echo ">>> Verificando container Elasticsearch..."

echo ">>> (Re)criando container Elasticsearch..."
docker stop "$ES_CONTAINER" 2>/dev/null || true
docker rm "$ES_CONTAINER" 2>/dev/null || true
echo "    Criando container Elasticsearch..."
docker run -d \
    --name "$ES_CONTAINER" \
    -p $ES_PORT:9200 \
    -p 9300:9300 \
        -e "discovery.type=single-node" \
        -e "xpack.security.enabled=false" \
        -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
        -e "ELASTIC_PASSWORD=$ES_PASSWORD" \
        docker.elastic.co/elasticsearch/elasticsearch:$ES_VERSION

    echo "    Aguardando inicialização do Elasticsearch (isso leva alguns segundos)..."
echo "    Aguardando serviço ficar disponível..."
for i in $(seq 1 30); do
    if curl -s "http://localhost:$ES_PORT" > /dev/null 2>&1; then
        echo "    Elasticsearch está disponível!"
        break
    fi
    sleep 2
done

echo "    Aguardando shards ficarem ativos..."
for i in $(seq 1 30); do
    status=$(curl -s "http://localhost:$ES_PORT/_cluster/health" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)
    if [ "$status" = "green" ] || [ "$status" = "yellow" ]; then
        echo "    Cluster status: $status"
        break
    fi
    sleep 2
done

echo "    Ajustando limites de disco do Elasticsearch (disco em 96%)..."
curl -s -X PUT "http://localhost:$ES_PORT/_cluster/settings" \
    -H "Content-Type: application/json" \
    -d '{
        "transient": {
            "cluster.routing.allocation.disk.watermark.low": "97%",
            "cluster.routing.allocation.disk.watermark.high": "98%",
            "cluster.routing.allocation.disk.watermark.flood_stage": "99%"
        }
    }' > /dev/null
echo "    Limites ajustados!"

echo ""

# ------------------------------------------------------------------
# 2. Função helper para chamadas HTTP
# ------------------------------------------------------------------
es_get() {
    local path=$1
    curl -s "http://localhost:$ES_PORT$path" | python3 -m json.tool 2>/dev/null
}

es_post() {
    local path=$1
    local data=$2
    curl -s -X POST "http://localhost:$ES_PORT$path" \
        -H "Content-Type: application/json" \
        -d "$data" | python3 -m json.tool 2>/dev/null
}

es_put() {
    local path=$1
    local data=$2
    curl -s -X PUT "http://localhost:$ES_PORT$path" \
        -H "Content-Type: application/json" \
        -d "$data" | python3 -m json.tool 2>/dev/null
}

es_delete() {
    local path=$1
    curl -s -X DELETE "http://localhost:$ES_PORT$path" | python3 -m json.tool 2>/dev/null
}

# ------------------------------------------------------------------
# 3. Verificar saúde do cluster
# ------------------------------------------------------------------
echo "================================================================"
echo "  1. Verificando saúde do cluster..."
echo "================================================================"
es_get "/_cluster/health"
echo ""

sleep 1

# ------------------------------------------------------------------
# 4. Criar índice (equivalente a uma "tabela" no SQL)
# ------------------------------------------------------------------
echo "================================================================"
echo "  2. Criando índice 'produtos'..."
echo "================================================================"

# Deleta o índice se existir
curl -s -X DELETE "http://localhost:$ES_PORT/produtos" > /dev/null 2>&1 || true

es_put "/produtos" '{
    "settings": {
        "number_of_shards": 1,
        "number_of_replicas": 0
    },
    "mappings": {
        "properties": {
            "nome": { "type": "text" },
            "descricao": { "type": "text" },
            "preco": { "type": "float" },
            "categoria": { "type": "keyword" },
            "tags": { "type": "keyword" },
            "estoque": { "type": "integer" },
            "data_criacao": { "type": "date" }
        }
    }
}' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('acknowledged',''))" 2>/dev/null
echo ""

echo "    Aguardando shards do índice produtos..."
curl -s "http://localhost:$ES_PORT/_cluster/health/produtos?wait_for_status=yellow&timeout=60s" > /dev/null
echo "    Índice pronto!"

sleep 1

# ------------------------------------------------------------------
# 5. Indexar documentos (inserir dados)
# ------------------------------------------------------------------
echo "================================================================"
echo "  3. Indexando documentos..."
echo "================================================================"

# Indexa vários produtos
es_post "/produtos/_doc" '{
    "nome": "Notebook Dell Inspiron",
    "descricao": "Notebook com processador Intel i7, 16GB RAM, SSD 512GB",
    "preco": 4500.00,
    "categoria": "Informática",
    "tags": ["notebook", "dell", "i7"],
    "estoque": 15,
    "data_criacao": "2025-01-15"
}'

es_post "/produtos/_doc" '{
    "nome": "Mouse Gamer Logitech",
    "descricao": "Mouse sem fio com 16000 DPI, RGB, 8 botões",
    "preco": 350.00,
    "categoria": "Informática",
    "tags": ["mouse", "gamer", "logitech"],
    "estoque": 42,
    "data_criacao": "2025-01-20"
}'

es_post "/produtos/_doc" '{
    "nome": "Monitor LG UltraWide",
    "descricao": "Monitor 29 polegadas ultrawide, IPS, 2560x1080",
    "preco": 1800.00,
    "categoria": "Informática",
    "tags": ["monitor", "lg", "ultrawide"],
    "estoque": 8,
    "data_criacao": "2025-02-01"
}'

es_post "/produtos/_doc" '{
    "nome": "Cadeira Ergonômica Flexform",
    "descricao": "Cadeira com suporte lombar, braços ajustáveis, encosto reclinável",
    "preco": 2200.00,
    "categoria": "Móveis",
    "tags": ["cadeira", "ergonômica", "escritório"],
    "estoque": 5,
    "data_criacao": "2025-02-10"
}'

es_post "/produtos/_doc" '{
    "nome": "Teclado Mecânico Corsair",
    "descricao": "Teclado mecânico RGB, switches Cherry MX Blue, cabo destacável",
    "preco": 650.00,
    "categoria": "Informática",
    "tags": ["teclado", "mecânico", "corsair"],
    "estoque": 20,
    "data_criacao": "2025-02-15"
}'

# Força refresh para tornar os documentos pesquisáveis
curl -s -X POST "http://localhost:$ES_PORT/produtos/_refresh" > /dev/null
echo ""
echo "Documentos indexados e prontos para busca."
echo ""

sleep 1

# ------------------------------------------------------------------
# 6. Buscas
# ------------------------------------------------------------------
echo "================================================================"
echo "  4. BUSCAS NO ELASTICSEARCH"
echo "================================================================"
echo ""

# 6.1 Busca por termo (term query — valor exato)
echo ">> Busca exata por categoria 'Informática':"
es_post "/produtos/_search" '{
    "query": {
        "term": { "categoria": "Informática" }
    }
}' | python3 -c "
import sys, json
d = json.load(sys.stdin)
hits = d['hits']['hits']
print(f'    Total: {d[\"hits\"][\"total\"][\"value\"]} resultados')
for h in hits:
    s = h['_source']
    print(f'    - {s[\"nome\"]} - R$ {s[\"preco\"]:.2f}')
"
echo ""

sleep 1

# 6.2 Busca textual (match query — busca por similaridade)
echo ">> Busca textual por 'notebook':"
es_post "/produtos/_search" '{
    "query": {
        "match": { "nome": "notebook" }
    }
}' | python3 -c "
import sys, json
d = json.load(sys.stdin)
hits = d['hits']['hits']
print(f'    Total: {d[\"hits\"][\"total\"][\"value\"]} resultados')
for h in hits:
    s = h['_source']
    print(f'    - {s[\"nome\"]} - Score: {h[\"_score\"]:.2f}')
"
echo ""

sleep 1

# 6.3 Busca com múltiplos campos (multi_match)
echo ">> Busca em múltiplos campos por 'gamer rgb':"
es_post "/produtos/_search" '{
    "query": {
        "multi_match": {
            "query": "gamer rgb",
            "fields": ["nome", "descricao", "tags"]
        }
    }
}' | python3 -c "
import sys, json
d = json.load(sys.stdin)
hits = d['hits']['hits']
print(f'    Total: {d[\"hits\"][\"total\"][\"value\"]} resultados')
for h in hits:
    s = h['_source']
    print(f'    - {s[\"nome\"]} - Score: {h[\"_score\"]:.2f}')
"
echo ""

sleep 1

# 6.4 Filtro + range (preço entre 500 e 2000)
echo ">> Filtro por faixa de preço (R\$ 500 a R\$ 2000):"
es_post "/produtos/_search" '{
    "query": {
        "bool": {
            "must": [
                { "match": { "categoria": "Informática" } }
            ],
            "filter": [
                { "range": { "preco": { "gte": 500, "lte": 2000 } } }
            ]
        }
    }
}' | python3 -c "
import sys, json
d = json.load(sys.stdin)
hits = d['hits']['hits']
print(f'    Total: {d[\"hits\"][\"total\"][\"value\"]} resultados')
for h in hits:
    s = h['_source']
    print(f'    - {s[\"nome\"]} - R$ {s[\"preco\"]:.2f}')
"
echo ""

sleep 1

# ------------------------------------------------------------------
# 7. Agregação (analytics)
# ------------------------------------------------------------------
echo "================================================================"
echo "  5. AGREGAÇÃO — Estatísticas por categoria"
echo "================================================================"

es_post "/produtos/_search" '{
    "size": 0,
    "aggs": {
        "por_categoria": {
            "terms": { "field": "categoria" },
            "aggs": {
                "preco_medio": { "avg": { "field": "preco" } },
                "total_estoque": { "sum": { "field": "estoque" } }
            }
        }
    }
}' | python3 -c "
import sys, json
d = json.load(sys.stdin)
buckets = d['aggregations']['por_categoria']['buckets']
print(f'    {\"Categoria\":20} {\"Qtd\":5} {\"Preço Médio\":15} {\"Estoque Total\":15}')
print(f'    {\"-\"*55}')
for b in buckets:
    print(f'    {b[\"key\"]:20} {b[\"doc_count\"]:5} R$ {b[\"preco_medio\"][\"value\"]:>8.2f} {b[\"total_estoque\"][\"value\"]:>8.0f}')
"
echo ""

sleep 1

# ------------------------------------------------------------------
# 8. Deletar um documento
# ------------------------------------------------------------------
echo "================================================================"
echo "  6. DELETANDO documento..."
echo "================================================================"

# Primeiro encontra o ID do primeiro documento
DOC_ID=$(curl -s "http://localhost:$ES_PORT/produtos/_search?size=1" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['hits']['hits'][0]['_id'])")

echo ">> Deletando documento ID: $DOC_ID"
curl -s -X DELETE "http://localhost:$ES_PORT/produtos/_doc/$DOC_ID" | python3 -m json.tool
echo ""

sleep 1

# ------------------------------------------------------------------
# 9. Deletar índice
# ------------------------------------------------------------------
echo "================================================================"
echo "  7. (Opcional) Deletar índice..."
echo "================================================================"
echo ">> Descomente a linha abaixo para deletar o índice:"
echo ">> curl -X DELETE \"http://localhost:$ES_PORT/produtos\""
echo ""

# ------------------------------------------------------------------
# 10. Conclusão
# ------------------------------------------------------------------
echo "================================================================"
echo "  EXPLICAÇÃO"
echo "================================================================"
echo ""
echo "Elasticsearch é um mecanismo de busca baseado no Apache Lucene:"
echo ""
echo "  - ÍNDICE: similar a uma 'tabela' no SQL"
echo "  - DOCUMENTO: similar a uma 'linha' (formato JSON)"
echo "  - MAPPING: similar ao 'schema' (define tipos dos campos)"
echo "  - SHARD: fragmento do índice (para escalabilidade)"
echo ""
echo "Principais tipos de consulta:"
echo ""
echo "  term        → busca por valor exato (categoria: 'Informática')"
echo "  match       → busca textual com relevância (TF-IDF/BM25)"
echo "  multi_match → busca em vários campos"
echo "  range       → filtro por faixa de valores"
echo "  bool        → combinação de cláusulas (must, should, filter)"
echo ""
echo "Elasticsearch é amplamente usado para:"
echo "  - Busca textual em sites e sistemas"
echo "  - Análise de logs (ELK Stack: Elastic + Logstash + Kibana)"
echo "  - Séries temporais e métricas"
echo ""

echo "Para parar o container:"
echo "  docker stop $ES_CONTAINER"
echo ""
echo "Demonstração Elasticsearch concluída!"
