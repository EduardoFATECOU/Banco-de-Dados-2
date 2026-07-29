#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# setup_completo.sh — Instalação completa para EC2 AWS
# Disciplinas: Banco de Dados II + Programação Web II
# SO: Ubuntu 22.04, 24.04 ou Debian 12
#
# Instala:
#   BD2  → MongoDB 7, Redis, Cassandra 4.1
#   PW2  → Apache2 + exemplos front-end
#
# Uso:
#   chmod +x setup_completo.sh
#   sudo ./setup_completo.sh
# =============================================================================

# ─── Cores ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✔]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✘]${NC} $1"; exit 1; }
sec()  { echo ""; echo -e "${CYAN}========== $1 ==========${NC}"; echo ""; }

# ─── Root check ──────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Execute com: sudo ./setup_completo.sh"

# ─── Detectar SO ─────────────────────────────────────────────────────────────
. /etc/os-release 2>/dev/null || err "SO não detectado."
ok "SO: $PRETTY_NAME"

# ─── IP privado ──────────────────────────────────────────────────────────────
IP_PRIV=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || \
          curl -s http://100.100.100.200/latest/meta-data/local-ipv4 2>/dev/null || \
          hostname -I | awk '{print $1}')
IP_PUB=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "IP_PUB_INDISPONIVEL")
ok "IP privado: $IP_PRIV  |  IP público: $IP_PUB"

# =============================================================================
# BANCO DE DADOS II — MongoDB, Redis, Cassandra
# =============================================================================
sec "BANCO DE DADOS II — Instalando MongoDB, Redis, Cassandra"

# ─── Dependências ────────────────────────────────────────────────────────────
apt update -y && apt upgrade -y

# Limpa repos MongoDB antigos (se houver)
rm -f /etc/apt/sources.list.d/mongodb*
rm -f /usr/share/keyrings/mongodb-server*

apt install -y gnupg curl wget lsb-release software-properties-common

# ─── MongoDB 7 ──────────────────────────────────────────────────────────────
sec "MongoDB 7.0"
case "$ID-$VERSION_CODENAME" in
    ubuntu-jammy)     MONGO_OS=ubuntu; MONGO_CODENAME=jammy; MONGO_VER="7.0" ;;
    ubuntu-noble)     MONGO_OS=ubuntu; MONGO_CODENAME=noble; MONGO_VER="8.0" ;;
    ubuntu-oracular)  MONGO_OS=ubuntu; MONGO_CODENAME=noble; MONGO_VER="8.0" ;;
    ubuntu-*)         MONGO_OS=ubuntu; MONGO_CODENAME=noble; MONGO_VER="8.0" ;;
    debian-bookworm)  MONGO_OS=debian; MONGO_CODENAME=bookworm; MONGO_VER="7.0" ;;
    debian-*)         MONGO_OS=debian; MONGO_CODENAME=bookworm; MONGO_VER="7.0" ;;
    *)                err "MongoDB: SO não suportado ($ID-$VERSION_CODENAME)." ;;
esac

curl -fsSL "https://pgp.mongodb.com/server-${MONGO_VER}.asc" | \
    gpg --dearmor -o /usr/share/keyrings/mongodb-server.gpg
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server.gpg ] https://repo.mongodb.org/apt/$MONGO_OS $MONGO_CODENAME/mongodb-org/$MONGO_VER multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org.list > /dev/null
apt-get update || err "Falha no repo MongoDB. Tente Ubuntu 22.04 ou 24.04."
apt install -y mongodb-org
sed -i "s/bindIp: 127.0.0.1/bindIp: 127.0.0.1,$IP_PRIV/" /etc/mongod.conf
service mongod start 2>/dev/null || mongod --fork --logpath /var/log/mongod.log --config /etc/mongod.conf
ok "MongoDB $MONGO_VER pronto"

# ─── Redis ──────────────────────────────────────────────────────────────────
sec "Redis"
apt install -y redis-server
cat <<EOF > /etc/redis/redis.conf
bind $IP_PRIV 127.0.0.1
port 6379
daemonize no
loglevel notice
save 900 1
save 300 10
save 60 10000
EOF
service redis-server restart 2>/dev/null || redis-server /etc/redis/redis.conf --daemonize yes
ok "Redis pronto"

# ─── Cassandra 4.1 ──────────────────────────────────────────────────────────
sec "Cassandra 4.1"
CAS_VER="4.1.7"; CAS_DIR="/opt/apache-cassandra-$CAS_VER"; CAS_LINK="/opt/cassandra"

CASSANDRA_VIA_APT=false
if [ "$ID" = "debian" ]; then
    curl -fsSL https://downloads.apache.org/cassandra/KEYS 2>/dev/null | \
        gpg --dearmor -o /usr/share/keyrings/cassandra-archive-keyring.gpg 2>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/cassandra-archive-keyring.gpg] https://downloads.apache.org/cassandra/debian 41x main" | \
        tee /etc/apt/sources.list.d/cassandra.sources.list > /dev/null
    apt-get update 2>/dev/null && apt install -y cassandra 2>/dev/null && CASSANDRA_VIA_APT=true
fi

if [ "$CASSANDRA_VIA_APT" = false ]; then
    warn "Usando tarball do Cassandra 4.1..."
    apt install -y openjdk-11-jre-headless
    CAS_URL="https://dlcdn.apache.org/cassandra/$CAS_VER/apache-cassandra-${CAS_VER}-bin.tar.gz"
    echo "Baixando $CAS_URL ..."
    curl -fsSL -o "/tmp/apache-cassandra-${CAS_VER}-bin.tar.gz" "$CAS_URL" || \
        curl -fsSL -o "/tmp/apache-cassandra-${CAS_VER}-bin.tar.gz" \
            "https://archive.apache.org/dist/cassandra/$CAS_VER/apache-cassandra-${CAS_VER}-bin.tar.gz" || \
        err "Falha ao baixar Cassandra de 2 mirrors."
    file "/tmp/apache-cassandra-${CAS_VER}-bin.tar.gz" | grep -q "gzip compressed" || \
        err "Arquivo baixado não é um gzip válido."
    tar -xzf "/tmp/apache-cassandra-${CAS_VER}-bin.tar.gz" -C /opt/
    ln -sfn "$CAS_DIR" "$CAS_LINK"

    JAVA_HOME=$(update-alternatives --list java 2>/dev/null | head -1 | sed 's|/bin/java||')
    [ -z "$JAVA_HOME" ] && JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))

    sed -i \
        -e "s/^cluster_name:.*/cluster_name: \"Aula NoSQL\"/" \
        -e "s/^listen_address:.*/listen_address: $IP_PRIV/" \
        -e "s/^rpc_address:.*/rpc_address: 0.0.0.0/" \
        -e "s/^broadcast_rpc_address:.*/broadcast_rpc_address: $IP_PRIV/" \
        -e "s/^endpoint_snitch:.*/endpoint_snitch: SimpleSnitch/" \
        -e "s/^# broadcast_address:.*/broadcast_address: $IP_PRIV/" \
        "$CAS_LINK/conf/cassandra.yaml"

    useradd -r -s /sbin/nologin -M cassandra 2>/dev/null
    mkdir -p /var/run/cassandra /var/log/cassandra /var/lib/cassandra
    chown -R cassandra:cassandra "$CAS_DIR" /var/run/cassandra /var/log/cassandra /var/lib/cassandra

    cat > /etc/systemd/system/cassandra.service <<EOF
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
    systemctl daemon-reload 2>/dev/null
    service cassandra start 2>/dev/null || warn "Iniciando Cassandra manualmente..."
    echo 'export PATH=$PATH:/opt/cassandra/bin' > /etc/profile.d/cassandra.sh
else
    if [ -f /etc/cassandra/cassandra.yaml ]; then
        sed -i \
            -e "s/^listen_address:.*/listen_address: $IP_PRIV/" \
            -e "s/^rpc_address:.*/rpc_address: 0.0.0.0/" \
            -e "s/^broadcast_rpc_address:.*/broadcast_rpc_address: $IP_PRIV/" \
            -e "s/^endpoint_snitch:.*/endpoint_snitch: SimpleSnitch/" \
            /etc/cassandra/cassandra.yaml
    fi
    service cassandra start 2>/dev/null || warn "Iniciando Cassandra (pode levar 2-3 min)..."
fi
ok "Cassandra 4.1 instalado"

# =============================================================================
# PROGRAMAÇÃO WEB II — Apache2 + exemplos front-end
# =============================================================================
sec "PROGRAMAÇÃO WEB II — Instalando Apache2 e copiando exemplos"

apt install -y apache2
service apache2 start 2>/dev/null || apachectl start
ok "Apache2 pronto"

# Copia exemplos do PW2
PW2_DESTINO="/var/www/html"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Tenta localizar a pasta de exemplos do PW2
if [ -d "$SCRIPT_DIR/01_Renderizacao_Cliente" ]; then
    PW2_ORIGEM="$SCRIPT_DIR"
elif [ -d "$SCRIPT_DIR/../../../Programação Web II/07_Exemplos_AWS_Debian" ]; then
    PW2_ORIGEM="$(cd "$SCRIPT_DIR/../../../Programação Web II/07_Exemplos_AWS_Debian" && pwd)"
else
    PW2_ORIGEM=""
fi

if [ -n "$PW2_ORIGEM" ]; then
    cp -r "$PW2_ORIGEM"/* "$PW2_DESTINO/"
    rm -f "$PW2_DESTINO/setup.sh" "$PW2_DESTINO/setup_completo.sh" "$PW2_DESTINO/README.md"
    chown -R www-data:www-data "$PW2_DESTINO"
    find "$PW2_DESTINO" -type d -exec chmod 755 {} \;
    find "$PW2_DESTINO" -type f -exec chmod 644 {} \;
    ok "Exemplos PW2 copiados para $PW2_DESTINO"
else
    warn "Pasta de exemplos PW2 não encontrada."
    warn "Copie manualmente os exemplos para $PW2_DESTINO"
fi

# ─── Firewall ────────────────────────────────────────────────────────────────
sec "Firewall (iptables)"
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -j DROP
apt install -y iptables-persistent 2>/dev/null
netfilter-persistent save 2>/dev/null || true
ok "Firewall configurado (portas 22, 80, 443 liberadas; bancos acessíveis via localhost)"

# =============================================================================
# VERIFICAÇÃO
# =============================================================================
sec "VERIFICANDO SERVIÇOS"

echo ""
echo "--- MongoDB ---"
mongosh --eval "db.version()" --quiet 2>/dev/null && ok "MongoDB OK" || warn "MongoDB: tente manualmente: mongosh"

echo ""
echo "--- Redis ---"
redis-cli ping 2>/dev/null | grep -q PONG && ok "Redis OK" || warn "Redis: tente manualmente: redis-cli ping"

echo ""
echo "--- Apache2 ---"
curl -s -o /dev/null -I http://localhost/ 2>/dev/null && ok "Apache2 OK" || warn "Apache2: tente manualmente: curl http://localhost/"

echo ""
echo "--- Cassandra (porta 9042) ---"
for i in $(seq 1 12); do
    nc -z 127.0.0.1 9042 2>/dev/null && { ok "Cassandra pronto (tentativa $i)"; break; }
    echo "  [$i/12] aguardando Cassandra..."
    sleep 15
done
CQLSH=$(command -v cqlsh || echo "$CAS_LINK/bin/cqlsh")
$CQLSH -e "DESCRIBE keyspaces;" 127.0.0.1 9042 2>/dev/null && ok "Cassandra OK" || \
    warn "Cassandra: tente manualmente depois: $CQLSH"

# =============================================================================
# RESUMO FINAL
# =============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                                                                    ║"
echo "║  Instalação concluída!                                            ║"
echo "║                                                                    ║"
echo "║  Banco de Dados II (acesso local):                                ║"
echo "║    MongoDB    → mongosh                                           ║"
echo "║    Redis      → redis-cli ping                                    ║"
echo "║    Cassandra  → cqlsh                                             ║"
echo "║                                                                    ║"
echo "║  Programação Web II (navegador):                                  ║"
echo "║    http://${IP_PUB}/                                      ║"
echo "║                                                                    ║"
echo "║  Security Group: liberar portas 22 (SSH) e 80 (HTTP)             ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
