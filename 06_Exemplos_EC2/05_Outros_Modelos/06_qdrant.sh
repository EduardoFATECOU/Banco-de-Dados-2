#!/usr/bin/env bash
# =============================================================================
# Exemplo de Qdrant — Banco de Dados Vetorial
#
# Qdrant é um banco de dados vetorial (vector database). Armazena
# embeddings (vetores numéricos) e permite busca por similaridade
# semântica usando métricas como cosine similarity ou dot product.
#
# Uso: chmod +x 06_qdrant.sh && ./06_qdrant.sh
# Requer: Docker instalado
# =============================================================================

set -e

echo "=== Liberando espaco em disco ==="
apt-get clean -qq 2>/dev/null || true
docker system prune -a -f 2>/dev/null || true
echo "=== Espaco apos limpeza ==="
df -h / | tail -1

echo "================================================================"
echo "  QDRANT — Banco de Dados Vetorial (Similaridade Semântica)"
echo "================================================================"
echo ""

QDRANT_CONTAINER="qdrant_banco2"
QDRANT_PORT=6333
QDRANT_GRPC_PORT=6334
COLECAO="filmes"

# ------------------------------------------------------------------
# 1. Iniciar Qdrant
# ------------------------------------------------------------------
echo ">>> (Re)criando container Qdrant..."
docker stop "$QDRANT_CONTAINER" 2>/dev/null || true
docker rm "$QDRANT_CONTAINER" 2>/dev/null || true
docker run -d \
    --name "$QDRANT_CONTAINER" \
    -p $QDRANT_PORT:6333 \
    -p $QDRANT_GRPC_PORT:6334 \
    qdrant/qdrant:v1.18.2

echo "    Qdrant disponivel em: http://localhost:$QDRANT_PORT"
echo "    Aguardando iniciar..."
sleep 5
echo ""

# ------------------------------------------------------------------
# 2. Criar collection (coleção de vetores)
# ------------------------------------------------------------------
echo ">>> Criando collection '$COLECAO' com vetores de tamanho 4..."
echo "    (Em producao, embeddings tem 384 a 1536 dimensoes)"

curl -s -X PUT "http://localhost:$QDRANT_PORT/collections/$COLECAO" \
    -H "Content-Type: application/json" \
    -d '{
        "vectors": {
            "size": 4,
            "distance": "Cosine"
        }
    }' 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'    Resultado: {d[\"result\"]}')" 2>/dev/null || true

echo ""

# ------------------------------------------------------------------
# 3. Inserir pontos (vectors + payload)
# ------------------------------------------------------------------
echo "=============================================================="
echo "  INSERINDO VETORES DE FILMES (embeddings simulados)"
echo "=============================================================="
echo ""

FILMES=(
    '{"id": 1, "vector": [0.9, 0.1, 0.2, 0.3], "payload": {"titulo": "Mad Max", "genero": "Acao", "ano": 2015}}'
    '{"id": 2, "vector": [0.1, 0.9, 0.2, 0.1], "payload": {"titulo": "Se Beber Nao Case", "genero": "Comedia", "ano": 2009}}'
    '{"id": 3, "vector": [0.2, 0.1, 0.9, 0.1], "payload": {"titulo": "O Poderoso Chefao", "genero": "Drama", "ano": 1972}}'
    '{"id": 4, "vector": [0.3, 0.1, 0.1, 0.9], "payload": {"titulo": "Interestelar", "genero": "Ficcao Cientifica", "ano": 2014}}'
    '{"id": 5, "vector": [0.8, 0.2, 0.3, 0.4], "payload": {"titulo": "John Wick", "genero": "Acao", "ano": 2014}}'
)

for FILME in "${FILMES[@]}"; do
    POINT_ID=$(echo "$FILME" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    curl -s -X PUT "http://localhost:$QDRANT_PORT/collections/$COLECAO/points" \
        -H "Content-Type: application/json" \
        -d "{\"points\": [$FILME]}" > /dev/null
    echo "    Filme $POINT_ID inserido"
done
echo ""

# ------------------------------------------------------------------
# 4. Busca por similaridade
# ------------------------------------------------------------------
echo "=============================================================="
echo "  BUSCA POR SIMILARIDADE"
echo "=============================================================="
echo ""

echo ">>> Buscando filmes similares a 'filme de acao'"
echo "    (vetor query: [0.85, 0.15, 0.1, 0.2])"
echo ""

QUERY_RESULT=$(curl -s -X POST "http://localhost:$QDRANT_PORT/collections/$COLECAO/points/search" \
    -H "Content-Type: application/json" \
    -d '{
        "vector": [0.85, 0.15, 0.1, 0.2],
        "limit": 3,
        "with_payload": true
    }' 2>/dev/null)

echo "$QUERY_RESULT" | python3 -c "
import sys, json

result = json.load(sys.stdin)
print('    Resultados:')
for point in result.get('result', []):
    payload = point.get('payload', {})
    score = point.get('score', 0)
    print(f'      - {payload.get(\"titulo\", \"?\")} ({payload.get(\"genero\", \"?\")}, {payload.get(\"ano\", \"?\")}) - score: {score:.4f}')
" 2>/dev/null || echo "    (erro ao processar resultado)"
echo ""

# ------------------------------------------------------------------
# 5. Explicacao
# ------------------------------------------------------------------
echo ""
echo "=============================================================="
echo "  EXPLICACAO"
echo "=============================================================="
echo ""
echo "  Qdrant e um banco de dados vetorial. Diferente de bancos"
echo "  tradicionais que buscam por igualdade exata, ele busca"
echo "  por SIMILARIDADE SEMANTICA entre vetores."
echo ""
echo "  Conceitos principais:"
echo "  - Collection: grupo de vetores (similar a uma tabela)"
echo "  - Vector: array numerico que representa um objeto"
echo "  - Payload: metadados associados ao vetor (JSON)"
echo "  - Distance: metrica de similaridade (Cosine, Dot, Euclidiana)"
echo ""
echo "  Aplicacoes reais:"
echo "  - Recomendacao de conteudo"
echo "  - Busca semantica (RAG - Retrieval Augmented Generation)"
echo "  - Deteccao de similaridade (plagio, duplicatas)"
echo "  - Sistemas de recomendacao"
echo "=============================================================="
echo ""

echo "Script Qdrant concluido."