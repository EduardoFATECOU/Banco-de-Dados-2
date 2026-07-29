#!/usr/bin/env bash
# setup_debian13.sh - MongoDB, Redis e Cassandra no Debian 13+ (Trixie+)
# Uso: chmod +x setup_debian13.sh && sudo ./setup_debian13.sh

VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; CIANO='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${VERDE}[OK]${NC} $1"; }
warn() { echo -e "${AMARELO}[!]${NC} $1"; }
erro() { echo -e "${VERMELHO}[ERR]${NC} $1"; }
sec()  { echo ""; echo -e "${CIANO}==============================${NC}"; echo -e "${CIANO}  $1${NC}"; echo -e "${CIANO}==============================${NC}"; echo ""; }

[[ $EUID -ne 0 ]] && { echo "Execute com: sudo ./setup_debian13.sh"; exit 1; }
. /etc/os-release 2>/dev/null || { echo "SO nao detectado."; exit 1; }
ok "SO: $PRETTY_NAME"

IP_PRIV=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || \
          hostname -I | awk '{print $1}')
ok "IP privado: $IP_PRIV"

sec "Atualizando pacotes"
apt update -y && apt upgrade -y
apt install -y gnupg curl wget lsb-release ca-certificates netcat-openbsd file

# =============================================================================
# REDIS
# =============================================================================
install_redis() {
    sec "Redis"
    apt install -y redis-server 2>/dev/null || { erro "Falha no Redis."; return 1; }
    ok "Redis instalado"

    cat <<EOF > /etc/redis/redis.conf
bind $IP_PRIV 127.0.0.1
port 6379
daemonize no
loglevel notice
save 900 1
save 300 10
save 60 10000
EOF

    timeout 5 systemctl restart redis-server 2>/dev/null || \
    timeout 5 systemctl restart redis 2>/dev/null || \
    redis-server /etc/redis/redis.conf --daemonize yes 2>/dev/null

    sleep 2
    if redis-cli ping 2>/dev/null | grep -q PONG; then
        ok "Redis OK"
    else
        warn "Redis: inicie manualmente: redis-server /etc/redis/redis.conf --daemonize yes"
    fi
}

# =============================================================================
# MONGODB
# =============================================================================
install_mongodb() {
    sec "MongoDB 7.0"
    install_mongodb_apt "debian" "bookworm" && return 0
    install_mongodb_apt "ubuntu" "noble" && return 0
    install_mongodb_apt "ubuntu" "jammy" && return 0
    warn "MongoDB via apt falhou. Tentando tarball..."
    install_mongodb_tarball
}

install_mongodb_apt() {
    local MONGO_OS=$1
    local MONGO_CODENAME=$2
    local MONGO_VER="7.0"

    rm -f /etc/apt/sources.list.d/mongodb* /usr/share/keyrings/mongodb-server*

    curl -fsSL "https://pgp.mongodb.com/server-${MONGO_VER}.asc" 2>/dev/null | \
        gpg --dearmor -o /usr/share/keyrings/mongodb-server.gpg 2>/dev/null || return 1

    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server.gpg ] https://repo.mongodb.org/apt/$MONGO_OS $MONGO_CODENAME/mongodb-org/$MONGO_VER multiverse" > /etc/apt/sources.list.d/mongodb-org.list

    apt-get update 2>/dev/null || return 1
    apt install -y mongodb-org 2>/dev/null || return 1

    sed -i "s/bindIp: 127.0.0.1/bindIp: 127.0.0.1,$IP_PRIV/" /etc/mongod.conf
    systemctl enable mongod 2>/dev/null || true
    timeout 10 systemctl start mongod 2>/dev/null || \
        mongod --fork --logpath /var/log/mongod.log --config /etc/mongod.conf

    sleep 3
    if mongosh --eval "db.version()" --quiet 2>/dev/null; then
        ok "MongoDB $MONGO_VER via apt ($MONGO_OS/$MONGO_CODENAME)"
        return 0
    fi
    return 1
}

install_mongodb_tarball() {
    local MONGO_VER="7.0"
    local MONGO_DIR="/opt/mongodb-$MONGO_VER"
    local MONGO_LINK="/opt/mongodb"
    apt install -y libcurl4 zstd 2>/dev/null || true

    local MONGO_FULL=""
    for patch in $(seq 0 30); do
        MONGO_FULL="${MONGO_VER}.${patch}"
        timeout 5 curl --output /dev/null --silent --head --fail \
            "https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-debian12-${MONGO_FULL}.tgz" && break
        MONGO_FULL=""
    done

    [ -z "$MONGO_FULL" ] && { erro "Nenhuma versao MongoDB 7.0 encontrada."; return 1; }

    warn "Baixando MongoDB $MONGO_FULL..."
    timeout 60 curl -fsSL -o /tmp/mongodb.tgz "https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-debian12-${MONGO_FULL}.tgz" || return 1
    file /tmp/mongodb.tgz | grep -q "gzip compressed" || { erro "Arquivo invalido."; return 1; }

    tar -xzf /tmp/mongodb.tgz -C /opt/
    local D=$(ls -d /opt/mongodb-linux-* 2>/dev/null | head -1)
    [ -z "$D" ] && { erro "Diretorio extraido nao encontrado."; return 1; }
    mv "$D" "$MONGO_DIR" && ln -sfn "$MONGO_DIR" "$MONGO_LINK"

    mkdir -p /var/lib/mongodb /var/log/mongodb
    useradd -r -s /sbin/nologin -M mongodb 2>/dev/null || true
    chown -R mongodb:mongodb /var/lib/mongodb /var/log/mongodb "$MONGO_DIR"

    cat > /etc/mongod.conf <<CONF
storage:
  dbPath: /var/lib/mongodb
  journal: { enabled: true }
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
net:
  port: 27017
  bindIp: 127.0.0.1,$IP_PRIV
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
CONF

    cat > /etc/systemd/system/mongod.service <<SVC
[Unit]
Description=MongoDB Database Server
After=network.target
[Service]
Type=forking
User=mongodb
Group=mongodb
ExecStart=$MONGO_LINK/bin/mongod --config /etc/mongod.conf --fork
ExecStop=$MONGO_LINK/bin/mongod --config /etc/mongod.conf --shutdown
PIDFile=/var/lib/mongodb/mongod.lock
LimitNOFILE=64000
[Install]
WantedBy=multi-user.target
SVC

    systemctl daemon-reload
    systemctl enable mongod 2>/dev/null || true
    timeout 10 systemctl start mongod 2>/dev/null || $MONGO_LINK/bin/mongod --config /etc/mongod.conf --fork
    echo "export PATH=\$PATH:$MONGO_LINK/bin" > /etc/profile.d/mongodb.sh
    sleep 3
    $MONGO_LINK/bin/mongosh --eval "db.version()" --quiet 2>/dev/null && \
        ok "MongoDB $MONGO_VER via tarball: OK" || \
        warn "MongoDB: sudo systemctl status mongod"
}

# =============================================================================
# CASSANDRA
# =============================================================================
install_cassandra() {
    sec "Apache Cassandra 4.1"
    install_cassandra_apt && return 0
    warn "Cassandra via apt falhou. Tentando tarball..."
    install_cassandra_tarball
}

install_cassandra_apt() {
    rm -f /etc/apt/sources.list.d/cassandra*

    curl -fsSL https://downloads.apache.org/cassandra/KEYS 2>/dev/null | \
        gpg --dearmor -o /usr/share/keyrings/cassandra-archive-keyring.gpg 2>/dev/null || return 1

    echo "deb [signed-by=/usr/share/keyrings/cassandra-archive-keyring.gpg] https://downloads.apache.org/cassandra/debian 41x main" > /etc/apt/sources.list.d/cassandra.sources.list

    apt-get update 2>/dev/null || return 1
    apt install -y cassandra 2>/dev/null || return 1

    if [ -f /etc/cassandra/cassandra.yaml ]; then
        sed -i \
            -e "s/^listen_address:.*/listen_address: $IP_PRIV/" \
            -e "s/^rpc_address:.*/rpc_address: 0.0.0.0/" \
            -e "s/^broadcast_rpc_address:.*/broadcast_rpc_address: $IP_PRIV/" \
            -e "s/^endpoint_snitch:.*/endpoint_snitch: SimpleSnitch/" \
            /etc/cassandra/cassandra.yaml
    fi

    timeout 10 systemctl start cassandra 2>/dev/null || true
    ok "Cassandra 4.1 via apt (aguarde 1-2 min...)"
    wait_cassandra_port
}

install_cassandra_tarball() {
    local CAS_LINK="/opt/cassandra"
    apt install -y openjdk-17-jre-headless 2>/dev/null || \
        apt install -y default-jre-headless 2>/dev/null || { erro "Falha ao instalar Java."; return 1; }

    # Tenta varias versoes 4.1.x ate achar uma existente
    local CAS_VER=""
    local CAS_DIR=""
    for patch in $(seq 0 30); do
        local VER="4.1.${patch}"
        local URL="https://dlcdn.apache.org/cassandra/$VER/apache-cassandra-${VER}-bin.tar.gz"
        if timeout 5 curl --output /dev/null --silent --head --fail "$URL"; then
            CAS_VER="$VER"
            CAS_DIR="/opt/apache-cassandra-$CAS_VER"
            ok "Encontrado Cassandra $CAS_VER"
            break
        fi
        # Tenta mirror alternativo
        URL="https://archive.apache.org/dist/cassandra/$VER/apache-cassandra-${VER}-bin.tar.gz"
        if timeout 5 curl --output /dev/null --silent --head --fail "$URL"; then
            CAS_VER="$VER"
            CAS_DIR="/opt/apache-cassandra-$CAS_VER"
            ok "Encontrado Cassandra $CAS_VER (archive)"
            break
        fi
    done

    [ -z "$CAS_VER" ] && { erro "Nenhuma versao Cassandra 4.1 encontrada."; return 1; }

    warn "Baixando Cassandra $CAS_VER..."
    timeout 120 curl -fsSL -o /tmp/cassandra.tgz \
        "https://dlcdn.apache.org/cassandra/$CAS_VER/apache-cassandra-${CAS_VER}-bin.tar.gz" || \
    timeout 120 curl -fsSL -o /tmp/cassandra.tgz \
        "https://archive.apache.org/dist/cassandra/$CAS_VER/apache-cassandra-${CAS_VER}-bin.tar.gz" || \
        { erro "Falha ao baixar Cassandra."; return 1; }

    file /tmp/cassandra.tgz | grep -q "gzip compressed" || { erro "Arquivo invalido."; return 1; }
    tar -xzf /tmp/cassandra.tgz -C /opt/
    ln -sfn "$CAS_DIR" "$CAS_LINK"

    local JAVA_HOME
    JAVA_HOME=$(update-alternatives --list java 2>/dev/null | head -1 | sed 's|/bin/java||')
    [ -z "$JAVA_HOME" ] && JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(which java)")")")

    sed -i \
        -e "s/^cluster_name:.*/cluster_name: \"Aula NoSQL\"/" \
        -e "s/^listen_address:.*/listen_address: $IP_PRIV/" \
        -e "s/^rpc_address:.*/rpc_address: 0.0.0.0/" \
        -e "s/^broadcast_rpc_address:.*/broadcast_rpc_address: $IP_PRIV/" \
        "$CAS_LINK/conf/cassandra.yaml"

    sed -i "s/^#MAX_HEAP_SIZE=.*/MAX_HEAP_SIZE=\"1G\"/" "$CAS_LINK/conf/cassandra-env.sh" 2>/dev/null || true
    sed -i "s/^#HEAP_NEWSIZE=.*/HEAP_NEWSIZE=\"256M\"/" "$CAS_LINK/conf/cassandra-env.sh" 2>/dev/null || true

    useradd -r -s /sbin/nologin -M cassandra 2>/dev/null || true
    mkdir -p /var/run/cassandra /var/log/cassandra /var/lib/cassandra
    chown -R cassandra:cassandra "$CAS_DIR" /var/run/cassandra /var/log/cassandra /var/lib/cassandra

    cat > /etc/systemd/system/cassandra.service <<SVC
[Unit]
Description=Apache Cassandra
After=network.target
[Service]
Type=simple
User=cassandra
Group=cassandra
ExecStart=$CAS_LINK/bin/cassandra -f
ExecStop=$CAS_LINK/bin/nodetool drain
Restart=on-failure
LimitNOFILE=100000
Environment=JAVA_HOME=$JAVA_HOME
[Install]
WantedBy=multi-user.target
SVC

    systemctl daemon-reload
    systemctl enable cassandra 2>/dev/null || true
    timeout 10 systemctl start cassandra 2>/dev/null || \
        su -s /bin/bash cassandra -c "$CAS_LINK/bin/cassandra" &

    echo 'export PATH=$PATH:/opt/cassandra/bin' > /etc/profile.d/cassandra.sh
    ok "Cassandra $CAS_VER via tarball (aguarde 2-3 min...)"
    wait_cassandra_port
}

wait_cassandra_port() {
    for i in $(seq 1 20); do
        nc -z 127.0.0.1 9042 2>/dev/null && { ok "Cassandra pronto (~$((i*10))s)"; return 0; }
        echo "  [$i/20] aguardando 10s..."
        sleep 10
    done
    warn "Cassandra: verifique depois com: cqlsh"
}

# =============================================================================
# EXECUCAO
# =============================================================================
install_redis
install_mongodb
install_cassandra

# =============================================================================
# VERIFICACAO
# =============================================================================
sec "VERIFICACAO FINAL"
echo "--- MongoDB ---"
command -v mongosh &>/dev/null && mongosh --eval "db.version()" --quiet 2>/dev/null && ok "MongoDB OK" || warn "MongoDB: tente: mongosh"
echo "--- Redis ---"
redis-cli ping 2>/dev/null | grep -q PONG && ok "Redis OK" || warn "Redis: tente: redis-cli ping"
echo "--- Cassandra ---"
CQLSH=$(command -v cqlsh || echo "/opt/cassandra/bin/cqlsh")
nc -z 127.0.0.1 9042 2>/dev/null && $CQLSH -e "DESCRIBE keyspaces;" 127.0.0.1 9042 2>/dev/null && ok "Cassandra OK" || warn "Cassandra: sudo systemctl status cassandra"

echo ""
echo "============================================"
echo "  Instalacao concluida!"
echo "  MongoDB    -> mongosh"
echo "  Redis      -> redis-cli ping"
echo "  Cassandra  -> cqlsh"
echo "============================================"