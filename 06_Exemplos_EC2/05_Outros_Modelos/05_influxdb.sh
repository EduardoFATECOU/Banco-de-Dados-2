#!/usr/bin/env bash
# =============================================================================
# Exemplo de InfluxDB — Banco de Dados Time-Series
#
# InfluxDB é otimizado para séries temporais: métricas de servidor,
# sensores IoT, dados financeiros, etc. Usa linguagem Flux (ou SQL
# no v3) para consultas com agregação por janela de tempo.
#
# Uso: chmod +x 05_influxdb.sh && ./05_influxdb.sh
# Requer: Docker instalado
# =============================================================================

set -e

echo "================================================================"
echo "  INFLUXDB — Banco de Dados de Séries Temporais"
echo "================================================================"
echo ""

INFLUX_CONTAINER="influxdb_banco2"
INFLUX_PORT=8086
INFLUX_TOKEN="meu-token-super-seguro"
INFLUX_ORG="banco2"
INFLUX_BUCKET="metricas_servidor"

# ------------------------------------------------------------------
# 1. Iniciar InfluxDB
# ------------------------------------------------------------------
echo ">>> Iniciando InfluxDB..."

if docker ps --format '{{.Names}}' | grep -q "^$INFLUX_CONTAINER$"; then
    echo "    Container '$INFLUX_CONTAINER' já está rodando."
elif docker ps -a --format '{{.Names}}' | grep -q "^$INFLUX_CONTAINER$"; then
    echo "    Container existe mas está parado. Iniciando..."
    docker start "$INFLUX_CONTAINER"
else
    docker run -d \
        --name "$INFLUX_CONTAINER" \
        -p $INFLUX_PORT:8086 \
        -e DOCKER_INFLUXDB_INIT_MODE=setup \
        -e DOCKER_INFLUXDB_INIT_USERNAME=admin \
        -e DOCKER_INFLUXDB_INIT_PASSWORD=senha123 \
        -e DOCKER_INFLUXDB_INIT_ORG=$INFLUX_ORG \
        -e DOCKER_INFLUXDB_INIT_BUCKET=$INFLUX_BUCKET \
        -e DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=$INFLUX_TOKEN \
        influxdb:2.7
fi

echo "    Aguardando InfluxDB iniciar..."
sleep 10
echo ""

# ------------------------------------------------------------------
# 2. Inserir dados (CPU, memória, disco)
# ------------------------------------------------------------------
echo ">>> Inserindo métricas de série temporal..."

# Dados no formato Line Protocol do InfluxDB
# Sintaxe: <measurement>,<tag>=<valor> <field>=<valor> [timestamp]
for i in $(seq 1 10); do
    TIMESTAMP=$(date -d "-$((10 - i)) seconds" +%s%N)
    TIMESTAMP_SEC=$(date -d "-$((10 - i)) seconds" +%s)

    # CPU
    curl -s -X POST "http://localhost:$INFLUX_PORT/api/v2/write?org=$INFLUX_ORG&bucket=$INFLUX_BUCKET&precision=ns" \
        -H "Authorization: Token $INFLUX_TOKEN" \
        -H "Content-Type: text/plain; charset=utf-8" \
        --data-binary "cpu,host=servidor1 percent=$((RANDOM % 100 + 1)) $TIMESTAMP" \
        > /dev/null

    # Memória
    curl -s -X POST "http://localhost:$INFLUX_PORT/api/v2/write?org=$INFLUX_ORG&bucket=$INFLUX_BUCKET&precision=ns" \
        -H "Authorization: Token $INFLUX_TOKEN" \
        -H "Content-Type: text/plain; charset=utf-8" \
        --data-binary "memoria,host=servidor1 uso_percent=$((RANDOM % 50 + 30)) disponivel_mb=$((RANDOM % 4000 + 1000)) $TIMESTAMP" \
        > /dev/null

    # Disco
    curl -s -X POST "http://localhost:$INFLUX_PORT/api/v2/write?org=$INFLUX_ORG&bucket=$INFLUX_BUCKET&precision=ns" \
        -H "Authorization: Token $INFLUX_TOKEN" \
        -H "Content-Type: text/plain; charset=utf-8" \
        --data-binary "disco,host=servidor1,particao=/dev/sda1 uso_percent=$((RANDOM % 40 + 40)) $TIMESTAMP" \
        > /dev/null

    echo "    Métrica $i/10 inserida (timestamp: $(date -d @$TIMESTAMP_SEC +%H:%M:%S))"
    sleep 0.3
done
echo ""

# ------------------------------------------------------------------
# 3. Consultar dados com Flux
# ------------------------------------------------------------------
echo "=============================================================="
echo "  CONSULTA FLUX: Média de CPU nos últimos 15 segundos"
echo "=============================================================="
echo ""

QUERY='from(bucket: "'$INFLUX_BUCKET'")
  |> range(start: -15s)
  |> filter(fn: (r) => r._measurement == "cpu" and r._field == "percent")
  |> mean()'

curl -s -X POST "http://localhost:$INFLUX_PORT/api/v2/query?org=$INFLUX_ORG" \
    -H "Authorization: Token $INFLUX_TOKEN" \
    -H "Content-Type: application/vnd.flux" \
    -d "$QUERY" 2>/dev/null | python3 -m json.tool 2>/dev/null || \
    echo "    (resposta em JSON exibida acima)"
echo ""

# ------------------------------------------------------------------
# 4. Listar buckets
# ------------------------------------------------------------------
echo "=============================================================="
echo "  LISTANDO BUCKETS"
echo "=============================================================="
curl -s -X GET "http://localhost:$INFLUX_PORT/api/v2/buckets" \
    -H "Authorization: Token $INFLUX_TOKEN" 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'    - {b[\"name\"]}') for b in d.get('buckets',[])]" 2>/dev/null
echo ""

# ------------------------------------------------------------------
# 5. Explicação
# ------------------------------------------------------------------
echo ""
echo "=============================================================="
echo "  EXPLICAÇÃO"
echo "=============================================================="
echo ""
echo "  InfluxDB é um banco Time-Series, otimizado para dados"
echo "  indexados por tempo (timestamps)."
echo ""
echo "  Conceitos principais:"
echo "  - Measurement: entidade monitorada (cpu, memoria, disco)"
echo "  - Tags: metadados indexáveis (host, particao)"
echo "  - Fields: valores numéricos (percent, uso_percent)"
echo "  - Timestamp: carimbo de tempo (nanossegundos)"
echo "  - Bucket: equivalente a um database (ex: '$INFLUX_BUCKET')"
echo ""
echo "  Diferenças para bancos relacionais:"
echo "  - Inserção e consulta otimizadas por intervalo de tempo"
echo "  - Compactação automática de dados antigos (downsampling)"
echo "  - Políticas de retenção (retenção automática por bucket)"
echo "=============================================================="
echo ""

echo "Script InfluxDB concluído."
