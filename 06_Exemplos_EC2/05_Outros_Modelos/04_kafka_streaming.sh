#!/usr/bin/env bash
# =============================================================================
# Exemplo de Kafka — Sistema de Streaming de Eventos
#
# Kafka é uma plataforma de streaming distribuída. Publica e assina
# fluxos de registros (tópicos), similar a um barramento de mensagens
# ou fila de publicação/assinatura.
#
# Uso: chmod +x 04_kafka_streaming.sh && ./04_kafka_streaming.sh
# Requer: Docker instalado
# =============================================================================

set -e
echo "=== Liberando espaco em disco ==="
apt-get clean -qq 2>/dev/null || true
docker system prune -a -f 2>/dev/null || true
echo "=== Espaco apos limpeza ==="
df -h / | tail -1


echo "================================================================"
echo "  KAFKA — Streaming de Eventos (Publish-Subscribe)"
echo "================================================================"
echo ""

KAFKA_CONTAINER="kafka_banco2"
TOPICO="pedidos"

# ------------------------------------------------------------------
# 1. Iniciar Kafka (modo KRaft, sem Zookeeper)
# ------------------------------------------------------------------
echo ">>> (Re)criando container Kafka..."
docker stop "$KAFKA_CONTAINER" 2>/dev/null || true
docker rm "$KAFKA_CONTAINER" 2>/dev/null || true
docker run -d \
    --name "$KAFKA_CONTAINER" \
    -p 9092:9092 \
    -e KAFKA_NODE_ID=1 \
    -e KAFKA_PROCESS_ROLES=broker,controller \
    -e KAFKA_CONTROLLER_QUORUM_VOTERS="1@localhost:9093" \
    -e KAFKA_LISTENERS="PLAINTEXT://:9092,CONTROLLER://:9093" \
    -e KAFKA_ADVERTISED_LISTENERS="PLAINTEXT://localhost:9092" \
    -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP="CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT" \
    -e KAFKA_CONTROLLER_LISTENER_NAMES="CONTROLLER" \
    -e KAFKA_INTER_BROKER_LISTENER_NAME="PLAINTEXT" \
    -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
    -e KAFKA_LOG_DIRS="/tmp/kraft-logs" \
    -e CLUSTER_ID="banco2-cluster" \
    apache/kafka:4.1.0

echo "    Aguardando Kafka iniciar..."
sleep 10
echo ""

# ------------------------------------------------------------------
# 2. Criar tópico
# ------------------------------------------------------------------
echo ">>> Criando tópico '$TOPICO'..."
docker exec "$KAFKA_CONTAINER" \
    /opt/kafka/bin/kafka-topics.sh --create \
    --topic "$TOPICO" \
    --bootstrap-server localhost:9092 \
    --partitions 3 \
    --replication-factor 1 2>/dev/null || \
    echo "    (tópico '$TOPICO' já existe)"
echo ""

# ------------------------------------------------------------------
# 3. Produtor — Publica eventos
# ------------------------------------------------------------------
echo "================================================================"
echo "  PRODUTOR: Publicando eventos no tópico '$TOPICO'"
echo "================================================================"

for i in $(seq 1 5); do
    MENSAGEM="{\"pedido_id\": $i, \"cliente\": \"Cliente_$i\", \"valor\": $((RANDOM % 1000 + 100)), \"timestamp\": \"$(date +%H:%M:%S)\"}"
    echo "$MENSAGEM" | docker exec -i "$KAFKA_CONTAINER" \
        /opt/kafka/bin/kafka-console-producer.sh \
        --topic "$TOPICO" \
        --bootstrap-server localhost:9092
    echo "    Evento $i publicado"
    sleep 0.5
done
echo ""

# ------------------------------------------------------------------
# 4. Consumidor — Lê eventos
# ------------------------------------------------------------------
echo "================================================================"
echo "  CONSUMIDOR: Lendo eventos do tópico '$TOPICO'"
echo "================================================================"
echo ""

docker exec "$KAFKA_CONTAINER" \
    /opt/kafka/bin/kafka-console-consumer.sh \
    --topic "$TOPICO" \
    --bootstrap-server localhost:9092 \
    --from-beginning \
    --max-messages 5 2>/dev/null || true
echo ""

# ------------------------------------------------------------------
# 5. Listar tópicos
# ------------------------------------------------------------------
echo "================================================================"
echo "  LISTANDO TÓPICOS"
echo "================================================================"
docker exec "$KAFKA_CONTAINER" \
    /opt/kafka/bin/kafka-topics.sh --list \
    --bootstrap-server localhost:9092 2>/dev/null || true
echo ""

# ------------------------------------------------------------------
# 6. Informações do tópico
# ------------------------------------------------------------------
echo "================================================================"
echo "  DETALHES DO TÓPICO '$TOPICO'"
echo "================================================================"
docker exec "$KAFKA_CONTAINER" \
    /opt/kafka/bin/kafka-topics.sh --describe \
    --topic "$TOPICO" \
    --bootstrap-server localhost:9092 2>/dev/null || true
echo ""

# ------------------------------------------------------------------
# 7. Conclusão
# ------------------------------------------------------------------
echo "================================================================"
echo "  EXPLICAÇÃO"
echo "================================================================"
echo ""
echo "Apache Kafka é uma plataforma de streaming de eventos:"
echo ""
echo "  - TÓPICO: canal onde os eventos são publicados"
echo "  - PRODUTOR: quem publica eventos no tópico"
echo "  - CONSUMIDOR: quem lê eventos do tópico"
echo "  - PARTIÇÃO: divisão do tópico para paralelismo"
echo "  - BROKER: servidor Kafka que armazena os eventos"
echo ""
echo "Diferente de filas tradicionais (RabbitMQ, Redis):"
echo "  - Eventos persistem em disco (não são removidos ao ler)"
echo "  - Múltiplos consumidores podem ler o mesmo evento"
echo "  - Suporte a replay (ler desde o início)"
echo "  - Escalabilidade horizontal por partições"
echo ""
echo "KRaft: modo sem Zookeeper (Kafka Raft Metadata)"
echo "  - A partir do Kafka 3.3, não precisa mais de Zookeeper"
echo "  - Metadata gerenciada internamente pelo Raft"
echo ""

echo "Para parar o container:"
echo "  docker stop $KAFKA_CONTAINER"
echo ""
echo "Demonstração Kafka concluída!"
