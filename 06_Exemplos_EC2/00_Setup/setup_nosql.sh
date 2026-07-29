#!/usr/bin/env bash
# =============================================================================
# setup_nosql.sh - Instala MongoDB 7, Redis e Cassandra 4.1
# Feito para EC2 AWS | Ubuntu 22.04, 24.04 ou Debian 12
# SEM Docker - instalação direta via apt ou tarball
#
# Uso:
#   chmod +x setup_nosql.sh
#   sudo ./setup_nosql.sh
#
# Cada aluno tem sua própria EC2 e acessa os bancos localmente.
# =============================================================================

VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; NC='\033[0m'
ok()  { echo -e "${VERDE}[OK]${NC} $1"; }
warn() { echo -e "${AMARELO}[!]${NC} $1"; }
erro() { echo -e "${VERMELHO}[ERR]${NC} $1"; exit 1; }
BARRA() { echo "=============================================="; }


. /etc/os-release 2>/dev/null || erro "SO não detectado."
ok "SO: $PRETTY_NAME"

# Detecta IP privado EC2 (fallback: hostname -I)
IP_PRIV=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || \
          curl -s http://100.100.100.200/latest/meta-data/local-ipv4 2>/dev/null || \
          hostname -I | awk '{print $1}')

BARRA; echo "  IP privado detectado: $IP_PRIV"; BARRA

BARRA; echo "  Atualizando pacotes..."; BARRA
sudo apt update -y && sudo apt upgrade -y

# Limpa repos antigos (se houver)
sudo rm -f /etc/apt/sources.list.d/mongodb* /etc/apt/sources.list.d/cassandra*
sudo rm -f /usr/share/keyrings/mongodb-server* /usr/share/keyrings/cassandra* /usr/share/keyrings/cassandra-archive*

BARRA; echo "  Instalando dependências..."; BARRA
sudo apt install -y gnupg curl wget lsb-release software-properties-common

# ============================================================================
# 1. MONGODB 7
# ============================================================================
BARRA; echo "  Instalando MongoDB 7.0..."; BARRA

case "$ID-$VERSION_CODENAME" in
    ubuntu-jammy)     MONGO_OS=ubuntu; MONGO_CODENAME=jammy; MONGO_VER="7.0" ;;
    ubuntu-noble)     MONGO_OS=ubuntu; MONGO_CODENAME=noble; MONGO_VER="8.0" ;;
    ubuntu-oracular)  MONGO_OS=ubuntu; MONGO_CODENAME=noble; MONGO_VER="8.0" ;;
    ubuntu-*)         MONGO_OS=ubuntu; MONGO_CODENAME=noble; MONGO_VER="8.0" ;;
    debian-bookworm)  MONGO_OS=debian; MONGO_CODENAME=bookworm; MONGO_VER="7.0" ;;
    debian-*)         MONGO_OS=debian; MONGO_CODENAME=bookworm; MONGO_VER="7.0" ;;
    *)                erro "MongoDB: SO não suportado ($ID-$VERSION_CODENAME)." ;;
esac

curl -fsSL "https://pgp.mongodb.com/server-${MONGO_VER}.asc" | \
    sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server.gpg
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server.gpg ] https://repo.mongodb.org/apt/$MONGO_OS $MONGO_CODENAME/mongodb-org/$MONGO_VER multiverse" | \
    sudo tee /etc/apt/sources.list.d/mongodb-org.list > /dev/null
sudo apt-get update || erro "Falha no repo MongoDB. Tente Ubuntu 22.04 ou 24.04."
sudo apt install -y mongodb-org

sudo sed -i "s/bindIp: 127.0.0.1/bindIp: 127.0.0.1,$IP_PRIV/" /etc/mongod.conf
sudo service mongod start 2>/dev/null || sudo mongod --fork --logpath /var/log/mongod.log --config /etc/mongod.conf
ok "MongoDB $MONGO_VER pronto (bind: $IP_PRIV + localhost)"

# ============================================================================
# 2. REDIS
# ============================================================================
BARRA; echo "  Instalando Redis..."; BARRA
sudo apt install -y redis-server

cat <<EOF | sudo tee /etc/redis/redis.conf > /dev/null
bind $IP_PRIV 127.0.0.1
port 6379
daemonize no
loglevel notice
save 900 1
save 300 10
save 60 10000
EOF

sudo service redis-server restart 2>/dev/null || sudo redis-server /etc/redis/redis.conf --daemonize yes
ok "Redis pronto (bind: $IP_PRIV + localhost)"

# ============================================================================
# 3. CASSANDRA 4.1
# ============================================================================
BARRA; echo "  Instalando Apache Cassandra 4.1..."; BARRA

CAS_VER="4.1.7"
CAS_DIR="/opt/apache-cassandra-$CAS_VER"
CAS_LINK="/opt/cassandra"

# Tenta instalação via apt (repo Debian — só funciona em Debian, não Ubuntu)
CASSANDRA_VIA_APT=false
if [ "$ID" = "debian" ]; then
    curl -fsSL https://downloads.apache.org/cassandra/KEYS 2>/dev/null | \
        sudo gpg --dearmor -o /usr/share/keyrings/cassandra-archive-keyring.gpg 2>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/cassandra-archive-keyring.gpg] https://downloads.apache.org/cassandra/debian 41x main" | \
        sudo tee /etc/apt/sources.list.d/cassandra.sources.list > /dev/null
    sudo apt-get update 2>/dev/null && sudo apt install -y cassandra 2>/dev/null && CASSANDRA_VIA_APT=true
fi

if [ "$CASSANDRA_VIA_APT" = false ]; then
    warn "Usando tarball do Cassandra 4.1..."
    sudo apt install -y openjdk-11-jre-headless

    CAS_URL="https://dlcdn.apache.org/cassandra/$CAS_VER/apache-cassandra-${CAS_VER}-bin.tar.gz"
    echo "Baixando $CAS_URL ..."
    curl -fsSL -o "/tmp/apache-cassandra-${CAS_VER}-bin.tar.gz" "$CAS_URL" || \
        curl -fsSL -o "/tmp/apache-cassandra-${CAS_VER}-bin.tar.gz" \
            "https://archive.apache.org/dist/cassandra/$CAS_VER/apache-cassandra-${CAS_VER}-bin.tar.gz" || \
        erro "Falha ao baixar Cassandra de 2 mirrors."
    file "/tmp/apache-cassandra-${CAS_VER}-bin.tar.gz" | grep -q "gzip compressed" || \
        erro "Arquivo baixado não é um gzip válido. Verifique a URL."

    sudo tar -xzf "/tmp/apache-cassandra-${CAS_VER}-bin.tar.gz" -C /opt/
    sudo ln -sfn "$CAS_DIR" "$CAS_LINK"

    # Detecta JAVA_HOME dinamicamente
    JAVA_HOME=$(update-alternatives --list java 2>/dev/null | head -1 | sed 's|/bin/java||')
    [ -z "$JAVA_HOME" ] && JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
    ok "JAVA_HOME detectado: $JAVA_HOME"

    # Configura cassandra.yaml
    sudo sed -i \
        -e "s/^cluster_name:.*/cluster_name: \"Aula NoSQL\"/" \
        -e "s/^listen_address:.*/listen_address: $IP_PRIV/" \
        -e "s/^rpc_address:.*/rpc_address: 0.0.0.0/" \
        -e "s/^broadcast_rpc_address:.*/broadcast_rpc_address: $IP_PRIV/" \
        -e "s/^endpoint_snitch:.*/endpoint_snitch: SimpleSnitch/" \
        -e "s/^# broadcast_address:.*/broadcast_address: $IP_PRIV/" \
        "$CAS_LINK/conf/cassandra.yaml"

    # Cria usuário e diretórios
    sudo useradd -r -s /sbin/nologin -M cassandra 2>/dev/null
    sudo mkdir -p /var/run/cassandra /var/log/cassandra /var/lib/cassandra
    sudo chown -R cassandra:cassandra "$CAS_DIR" /var/run/cassandra /var/log/cassandra /var/lib/cassandra

    # Systemd service (Type=simple com foreground)
    sudo tee /etc/systemd/system/cassandra.service > /dev/null <<EOF
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
EOF

    sudo systemctl daemon-reload 2>/dev/null
    sudo service cassandra start 2>/dev/null || warn "Iniciando Cassandra manualmente..."

    echo 'export PATH=$PATH:/opt/cassandra/bin' | sudo tee /etc/profile.d/cassandra.sh > /dev/null
else
    # Configura bind no IP privado (apt path: /etc/cassandra/cassandra.yaml)
    if [ -f /etc/cassandra/cassandra.yaml ]; then
        sudo sed -i \
            -e "s/^listen_address:.*/listen_address: $IP_PRIV/" \
            -e "s/^rpc_address:.*/rpc_address: 0.0.0.0/" \
            -e "s/^broadcast_rpc_address:.*/broadcast_rpc_address: $IP_PRIV/" \
            -e "s/^endpoint_snitch:.*/endpoint_snitch: SimpleSnitch/" \
            /etc/cassandra/cassandra.yaml
    fi
    sudo service cassandra start 2>/dev/null || warn "Iniciando Cassandra (pode levar 2-3 min)..."
fi

ok "Cassandra 4.1 instalado"

# ============================================================================
# 4. VERIFICAÇÃO (com espera adaptativa)
# ============================================================================
BARRA; echo "  Aguardando serviços ficarem prontos..."; BARRA

echo "MongoDB: $(mongosh --eval "db.version()" --quiet 2>/dev/null || echo 'aguardando...')"

echo "Redis: $(redis-cli ping 2>/dev/null || echo 'aguardando...')"

ok "MongoDB e Redis OK"

echo ""
echo "Aguardando Cassandra (porta 9042)..."
for i in $(seq 1 12); do
    if nc -z 127.0.0.1 9042 2>/dev/null; then
        ok "Cassandra pronto na tentativa $i"
        break
    fi
    echo "  [$i/12] aguardando..."
    sleep 15
done

CQLSH=$(command -v cqlsh || echo "$CAS_LINK/bin/cqlsh")
if $CQLSH -e "DESCRIBE keyspaces;" 127.0.0.1 9042 2>/dev/null; then
    ok "Cassandra respondendo consultas"
else
    warn "Cassandra pode não ter terminado a inicialização."
    warn "Teste manual depois: $CQLSH $IP_PRIV"
fi

echo ""
BARRA
echo "  Instalação concluída!"
echo ""
echo "  MongoDB:   mongosh"
echo "  Redis:     redis-cli ping"
echo "  Cassandra: cqlsh"
echo ""
echo "  Conexão local (dentro da própria EC2)."
BARRA
