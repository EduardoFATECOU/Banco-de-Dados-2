#!/usr/bin/env bash
# =============================================================================
# Exemplo de MinIO — Armazenamento de Objetos (S3-compatible)
#
# MinIO é um servidor de armazenamento de objetos compatível com a
# API S3 da AWS. Ideal para armazenar arquivos binários, imagens,
# vídeos, backups e qualquer dado não-estruturado.
#
# Uso: chmod +x 07_minio.sh && ./07_minio.sh
# Requer: Docker instalado
# =============================================================================

set -e

echo "================================================================"
echo "  MINIO — Armazenamento de Objetos (S3-compatible)"
echo "================================================================"
echo ""

MINIO_CONTAINER="minio_banco2"
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_USER="minioadmin"
MINIO_PASS="minioadmin"
BUCKET="fotos"

# ------------------------------------------------------------------
# 1. Iniciar MinIO
# ------------------------------------------------------------------
echo ">>> Iniciando MinIO..."

if docker ps --format '{{.Names}}' | grep -q "^$MINIO_CONTAINER$"; then
    echo "    Container '$MINIO_CONTAINER' já está rodando."
elif docker ps -a --format '{{.Names}}' | grep -q "^$MINIO_CONTAINER$"; then
    echo "    Container existe mas está parado. Iniciando..."
    docker start "$MINIO_CONTAINER"
else
    docker run -d \
        --name "$MINIO_CONTAINER" \
        -p $MINIO_PORT:9000 \
        -p $MINIO_CONSOLE_PORT:9001 \
        -e MINIO_ROOT_USER=$MINIO_USER \
        -e MINIO_ROOT_PASSWORD=$MINIO_PASS \
        minio/minio server /data --console-address ":$MINIO_CONSOLE_PORT"
fi

echo "    MinIO disponível em:"
echo "      - API S3:  http://localhost:$MINIO_PORT"
echo "      - Console: http://localhost:$MINIO_CONSOLE_PORT"
echo "      - Usuário: $MINIO_USER / $MINIO_PASS"
echo "    Aguardando iniciar..."
sleep 5
echo ""

# ------------------------------------------------------------------
# 2. Configurar alias mc (MinIO Client via Docker)
# ------------------------------------------------------------------
echo ">>> Configurando cliente MinIO (mc)..."

# Usamos um container auxiliar com o mc
MC_ALIAS="local"
docker exec "$MINIO_CONTAINER" mc alias set $MC_ALIAS http://localhost:9000 $MINIO_USER $MINIO_PASS > /dev/null 2>&1 || true

echo "    Alias '$MC_ALIAS' configurado."
echo ""

# ------------------------------------------------------------------
# 3. Criar bucket
# ------------------------------------------------------------------
echo ">>> Criando bucket '$BUCKET'..."
docker exec "$MINIO_CONTAINER" mc mb "$MC_ALIAS/$BUCKET" 2>/dev/null && \
    echo "    Bucket '$BUCKET' criado." || \
    echo "    Bucket '$BUCKET' já existe."
echo ""

# ------------------------------------------------------------------
# 4. Upload de arquivos
# ------------------------------------------------------------------
echo "=============================================================="
echo "  UPLOAD DE ARQUIVOS"
echo "=============================================================="
echo ""

# Criar arquivos de exemplo
echo "Conteudo do relatorio PDF falso" > /tmp/relatorio.txt
echo '{"nome": "Joao", "idade": 30, "cidade": "Sao Paulo"}' > /tmp/usuario.json
echo "imagem binaria simulada" > /tmp/foto_perfil.png

docker cp /tmp/relatorio.txt "$MINIO_CONTAINER:/tmp/relatorio.txt"
docker cp /tmp/usuario.json "$MINIO_CONTAINER:/tmp/usuario.json"
docker cp /tmp/foto_perfil.png "$MINIO_CONTAINER:/tmp/foto_perfil.png"

docker exec "$MINIO_CONTAINER" mc cp /tmp/relatorio.txt "$MC_ALIAS/$BUCKET/documentos/" > /dev/null
echo "    relatorio.txt -> $BUCKET/documentos/"

docker exec "$MINIO_CONTAINER" mc cp /tmp/usuario.json "$MC_ALIAS/$BUCKET/dados/" > /dev/null
echo "    usuario.json -> $BUCKET/dados/"

docker exec "$MINIO_CONTAINER" mc cp /tmp/foto_perfil.png "$MC_ALIAS/$BUCKET/imagens/" > /dev/null
echo "    foto_perfil.png -> $BUCKET/imagens/"

echo ""

# ------------------------------------------------------------------
# 5. Listar arquivos
# ------------------------------------------------------------------
echo "=============================================================="
echo "  LISTANDO ARQUIVOS NO BUCKET"
echo "=============================================================="
docker exec "$MINIO_CONTAINER" mc ls -r "$MC_ALIAS/$BUCKET"
echo ""

# ------------------------------------------------------------------
# 6. Download de arquivo
# ------------------------------------------------------------------
echo "=============================================================="
echo "  DOWNLOAD (simulação)"
echo "=============================================================="
docker exec "$MINIO_CONTAINER" mc cp "$MC_ALIAS/$BUCKET/documentos/relatorio.txt" /tmp/download_relatorio.txt > /dev/null
echo "    Download de 'documentos/relatorio.txt' realizado."
echo "    Conteúdo: $(docker exec "$MINIO_CONTAINER" cat /tmp/download_relatorio.txt)"
echo ""

# ------------------------------------------------------------------
# 7. Explicação
# ------------------------------------------------------------------
echo ""
echo "=============================================================="
echo "  EXPLICAÇÃO"
echo "=============================================================="
echo ""
echo "  MinIO implementa a API S3 da AWS para armazenamento de"
echo "  objetos (blobs). Diferenças para sistemas de arquivos:"
echo ""
echo "  - Bucket: recipiente de objetos (como um diretório raiz)"
echo "  - Objeto: arquivo + metadados (até 5TB por objeto)"
echo "  - Chave (key): caminho do objeto dentro do bucket"
echo "  - Versionamento: múltiplas versões do mesmo objeto"
echo "  - Policy: controle de acesso por bucket/prefixo"
echo ""
echo "  Casos de uso:"
echo "  - Armazenamento de imagens, vídeos, backups"
echo "  - Data Lakes (campos brutos de dados)"
echo "  - Static hosting de sites"
echo "  - Compatível com ferramentas S3 (AWS CLI, boto3)"
echo "=============================================================="
echo ""

echo "Script MinIO concluído."
