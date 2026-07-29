#!/usr/bin/env bash
# ==============================================================================
# setup_docker.sh - Instala Docker + MongoDB 7 + Redis 7 + Cassandra 4.1
# Uso: chmod +x setup_docker.sh && sudo ./setup_docker.sh
# ==============================================================================
set -euo pipefail
log() { echo "[$(date +%H:%M:%S)] $*"; }

log "=== Liberando espaco em disco ==="
apt-get clean -qq 2>/dev/null || true
docker system prune -a -f 2>/dev/null || true
log "=== Espaco apos limpeza ==="
df -h / | tail -1

log "=== Removendo instalacao anterior do Docker (se houver) ==="
apt-get remove -y -qq docker.io docker-ce docker-ce-cli containerd.io 2>/dev/null || true
apt-get autoremove -y -qq 2>/dev/null || true

log "=== Instalando Docker (via script oficial) ==="
apt-get update -qq
apt-get install -y -qq curl ca-certificates
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

log "=== Criando diretorio /opt/banco2 ==="
mkdir -p /opt/banco2

log "=== Gerando docker-compose.yml ==="

cat > /opt/banco2/docker-compose.yml << 'COMPOSE_EOF'
services:

  mongodb:
    image: mongo:7
    container_name: mongodb_banco2
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db
      - mongodb_config:/data/configdb
    environment:
      MONGO_INITDB_DATABASE: admin
    restart: unless-stopped
    networks:
      - bancos_net

  redis:
    image: redis:7-alpine
    container_name: redis_banco2
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes --loglevel warning
    restart: unless-stopped
    networks:
      - bancos_net

  cassandra:
    image: cassandra:4.1
    container_name: cassandra_banco2
    ports:
      - "9042:9042"
    volumes:
      - cassandra_data:/var/lib/cassandra
    environment:
      CASSANDRA_CLUSTER_NAME: "BancoDeDadosII"
      CASSANDRA_NUM_TOKENS: 256
      CASSANDRA_DC: "datacenter1"
      CASSANDRA_RACK: "rack1"
      HEAP_NEWSIZE: 128M
      MAX_HEAP_SIZE: 512M
    restart: unless-stopped
    networks:
      - bancos_net

volumes:
  mongodb_data:
  mongodb_config:
  redis_data:
  cassandra_data:

networks:
  bancos_net:
    driver: bridge
COMPOSE_EOF

log "=== Iniciando containers ==="
cd /opt/banco2
docker compose -p banco2 up -d

log "=== Criando atalhos CLI ==="
cat > /usr/local/bin/mongosh << 'EOF'
#!/usr/bin/env bash
exec docker exec -i mongodb_banco2 mongosh "$@"
EOF

cat > /usr/local/bin/redis-cli << 'EOF'
#!/usr/bin/env bash
exec docker exec -i redis_banco2 redis-cli "$@"
EOF

cat > /usr/local/bin/cqlsh << 'EOF'
#!/usr/bin/env bash
exec docker exec -i cassandra_banco2 cqlsh "$@"
EOF

chmod +x /usr/local/bin/mongosh /usr/local/bin/redis-cli /usr/local/bin/cqlsh

log "=== VERIFICANDO ==="
sleep 3
echo ""
echo "MongoDB:";   mongosh --quiet --eval "db.version()" 2>&1 || echo "  (ainda iniciando)"
echo "Redis:";     redis-cli ping 2>&1                    || echo "  (ainda iniciando)"
echo "Cassandra:"; cqlsh -e "SELECT release_version FROM system.local;" 2>&1 || echo "  (ainda iniciando, aguarde 2-3 min)"

log ""
log "=== PRONTO! ==="
log "Comandos disponiveis: mongosh, redis-cli, cqlsh"
log "Para ver status: cd /opt/banco2 && docker compose ps"
log "Cassandra pode levar 2-3 minutos para ficar pronto."
