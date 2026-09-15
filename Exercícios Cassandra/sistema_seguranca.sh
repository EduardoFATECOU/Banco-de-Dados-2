#!/bin/bash

# Nome do contêiner Docker do Cassandra
CONTAINER_NAME="cassandra_banco2" 

# Função para testar a conexão com o contêiner
verificar_conexao() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "❌ ERRO: O contêiner '$CONTAINER_NAME' não está rodando."
        read -p "Digite o nome do contêiner: " CONTAINER_NAME
        if [ -z "$CONTAINER_NAME" ]; then exit 1; fi
    fi
}

# Executa comandos CQL dentro do contêiner
executar_cql() {
    local cql_query="$1"
    docker exec -i "$CONTAINER_NAME" cqlsh -e "$cql_query"
}

# Inicializa o banco de dados de segurança
configurar_banco() {
    echo "⚙️  Ativando diretivas de segurança e criptografia..."
    executar_cql "CREATE KEYSPACE IF NOT EXISTS seguranca WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};"
    
    # Tabela de Usuários (Senha salva apenas como Hash SHA-256)
    executar_cql "
    CREATE TABLE IF NOT EXISTS seguranca.usuarios (
        usuario text PRIMARY KEY,
        senha_hash text,
        nivel_acesso text
    );"

    # Tabela de Auditoria (Time-Series de acessos)
    executar_cql "
    CREATE TABLE IF NOT EXISTS seguranca.auditoria (
        usuario text,
        horario timestamp,
        status text,
        ip_origem text,
        PRIMARY KEY (usuario, horario)
    ) WITH CLUSTERING ORDER BY (horario DESC);"
}

# LÓGICA DE SEGURANÇA: Função para gerar Hash SHA-256
gerar_hash() {
    local senha_pura="$1"
    # Gera o hash SHA-256 usando o OpenSSL de forma limpa
    echo -n "$senha_pura" | openssl dgst -sha256 | awk '{print $2}'
}

# [C]REATE - Cadastro de Novo Usuário (IAM)
cadastrar_usuario() {
    clear
    echo "=== 🔐 CADASTRO DE USUÁRIO (SISTEMA IAM) ==="
    read -p "Nome de Usuário (Username): " usuario
    read -s -p "Senha de Acesso: " senha
    echo ""
    read -p "Nível de Permissão (ADMIN, USER, GUEST): " nivel

    # Transforma o username em minúsculo para padronizar
    usuario=$(echo "$usuario" | tr '[:upper:]' '[:lower:]')
    nivel=$(echo "$nivel" | tr '[:lower:]' '[:upper:]')

    if [ -z "$usuario" ] || [ -z "$senha" ] || [ -z "$nivel" ]; then
        echo "⚠️  Todos os campos são obrigatórios!"
        read -p "Pressione [Enter] para continuar..."
        return
    fi

    # Aplica a lógica matemática/criptográfica do SHA-256 na senha
    local hash_calculado=$(gerar_hash "$senha")

    # Insere as credenciais protegidas no Cassandra
    executar_cql "INSERT INTO seguranca.usuarios (usuario, senha_hash, nivel_acesso) VALUES ('$usuario', '$hash_calculado', '$nivel');"
    
    echo "✅ Usuário registrado com segurança usando criptografia SHA-256!"
    read -p "Pressione [Enter] para voltar ao menu..."
}

# [R]EAD + AUTH LOGIC - Tela de Autenticação (Login)
realizar_login() {
    clear
    echo "=== 🔒 TELA DE AUTENTICAÇÃO DO SISTEMA ==="
    read -p "Usuário: " usuario
    read -s -p "Senha: " senha
    echo ""

    usuario=$(echo "$usuario" | tr '[:upper:]' '[:lower:]')
    local ip_ficticio="192.168.1.$(( (RANDOM % 254) + 1 ))" # Simula um IP de origem

    # Busca o hash e o nível do usuário no Cassandra
    local raw_data=$(executar_cql "SELECT senha_hash, nivel_acesso FROM seguranca.usuarios WHERE usuario='$usuario';")
    
    local hash_banco=$(echo "$raw_data" | awk -F'|' 'NR==4 {print $1}' | xargs)
    local nivel_banco=$(echo "$raw_data" | awk -F'|' 'NR==4 {print $2}' | xargs)

    if [ -z "$hash_banco" ] || [ "$hash_banco" == "null" ]; then
        echo "❌ Acesso Negado! Usuário ou senha incorretos."
        # Registra a falha na tabela de auditoria temporal
        executar_cql "INSERT INTO seguranca.auditoria (usuario, horario, status, ip_origem) VALUES ('$usuario', toTimestamp(now()), 'FALHA: USUARIO INEXISTENTE', '$ip_ficticio');"
        read -p "Pressione [Enter] para continuar..."
        return
    fi

    # Calcula o hash da senha que o usuário digitou agora para comparar
    local hash_digitado=$(gerar_hash "$senha")

    # Lógica de validação segura por comparação de hashes
    if [ "$hash_digitado" == "$hash_banco" ]; then
        echo "🔓 ACESSO AUTORIZADO!"
        echo "Bem-vindo, $usuario. Seu nível de acesso é: [$nivel_banco]"
        
        # Registra o sucesso na auditoria do Cassandra
        executar_cql "INSERT INTO seguranca.auditoria (usuario, horario, status, ip_origem) VALUES ('$usuario', toTimestamp(now()), 'SUCESSO: LOGIN REALIZADO ($nivel_banco)', '$ip_ficticio');"
    else
        echo "❌ Acesso Negado! Usuário ou senha incorretos."
        # Registra a tentativa de invasão ou erro de senha
        executar_cql "INSERT INTO seguranca.auditoria (usuario, horario, status, ip_origem) VALUES ('$usuario', toTimestamp(now()), 'FALHA: SENHA INCORRETA', '$ip_ficticio');"
    fi

    read -p "Pressione [Enter] para voltar ao menu..."
}

# [R]EAD - Painel de Auditoria de Segurança
ver_logs_auditoria() {
    clear
    echo "=== 🕵️♂️ PAINEL DE AUDITORIA (LOGS DE SEGURANÇA) ==="
    read -p "Digite o usuário para rastrear (ou deixe em branco para ver todos): " usuario
    usuario=$(echo "$usuario" | tr '[:upper:]' '[:lower:]')

    echo "Buscando registros na linha do tempo do Cassandra..."
    echo "------------------------------------------------------------------------"

    if [ -z "$usuario" ]; then
        # Exibe os logs gerais do sistema
        executar_cql "SELECT usuario, horario, status, ip_origem FROM seguranca.auditoria LIMIT 20;"
    else
        # Exibe ordenado de forma cronológica reversa nativa do Cassandra para o usuário específico
        executar_cql "SELECT horario, status, ip_origem FROM seguranca.auditoria WHERE usuario='$usuario';"
    fi

    echo "------------------------------------------------------------------------"
    read -p "Pressione [Enter] para voltar ao menu..."
}

# Fluxo Principal
verificar_conexao
configurar_banco

while true; do
    clear
    echo "======================================"
    echo "     CYBERSECURITY & IAM ENGINES      "
    echo "      (Cassandra Secure Vault)        "
    echo "======================================"
    echo "1) Cadastrar Novo Usuário (Criptografar)"
    echo "2) Autenticar / Fazer Login (Validar Hash)"
    echo "3) Ver Logs de Auditoria (Trilha de Segurança)"
    echo "4) Sair do Terminal"
    echo "======================================"
    read -p "Selecione o protocolo de segurança: " opcao

    case $opcao in
        1) cadastrar_usuario ;;
        2) realizar_login ;;
        3) ver_logs_auditoria ;;
        4) echo "Encerrando sistemas de proteção..."; exit 0 ;;
        *) echo "Opção inválida!"; sleep 1 ;;
    esac
done