#!/bin/bash

# ==========================================
# CONFIGURAÇÃO: Ajuste o nome do contêiner aqui
# ==========================================
CONTAINER_NAME="cassandra_banco2" 

# Função para testar a conexão com o contêiner
verificar_conexao() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "❌ ERRO: O contêiner '$CONTAINER_NAME' não está rodando."
        echo "Contêineres ativos no momento:"
        docker ps --format "- {{.Names}}"
        echo ""
        read -p "Digite o nome correto do contêiner do Cassandra: " CONTAINER_NAME
        if [ -z "$CONTAINER_NAME" ]; then exit 1; fi
    fi
}

# Executa comandos CQL dentro do contêiner Docker
executar_cql() {
    local cql_query="$1"
    # Usando -i sem o -t para evitar erros de falta de TTY em scripts bash
    docker exec -i "$CONTAINER_NAME" cqlsh -e "$cql_query"
}

# Inicializa o banco (Keyspace e Tabela)
configurar_banco() {
    echo "⚙️  Verificando estrutura do banco de dados..."
    executar_cql "CREATE KEYSPACE IF NOT EXISTS sistema_crud WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};"
    executar_cql "CREATE TABLE IF NOT EXISTS sistema_crud.usuarios (id int PRIMARY KEY, nome text, email text);"
}

# [C]REATE - Inserir Usuário
criar_usuario() {
    clear
    echo "=== 📝 CADASTRAR NOVO USUÁRIO ==="
    read -p "Digite o ID (apenas números): " id
    read -p "Digite o Nome: " nome
    read -p "Digite o Email: " email

    if [[ ! "$id" =~ ^[0-9]+$ ]] || [ -z "$nome" ] || [ -z "$email" ]; then
        echo "⚠️  Dados inválidos. O ID precisa ser numérico e nenhum campo pode ficar vazio."
    else
        executar_cql "INSERT INTO sistema_crud.usuarios (id, nome, email) VALUES ($id, '$nome', '$email');"
        echo "✅ Usuário cadastrado com sucesso!"
    fi
    read -p "Pressione [Enter] para voltar ao menu..."
}

# [R]EAD - Listar Usuários
listar_usuarios() {
    clear
    echo "=== 📋 LISTA DE USUÁRIOS CADASTRADOS ==="
    executar_cql "SELECT id, nome, email FROM sistema_crud.usuarios;"
    echo "========================================"
    read -p "Pressione [Enter] para voltar ao menu..."
}

# [U]PDATE - Atualizar Usuário
atualizar_usuario() {
    clear
    echo "=== 🔄 ATUALIZAR EMAIL DE USUÁRIO ==="
    read -p "Digite o ID do usuário que deseja alterar: " id
    read -p "Digite o NOVO Email: " novo_email

    if [[ ! "$id" =~ ^[0-9]+$ ]] || [ -z "$novo_email" ]; then
        echo "⚠️  Campos inválidos."
    else
        # Cassandra faz UPSERT, mas vamos validar atualizando o campo
        executar_cql "UPDATE sistema_crud.usuarios SET email = '$novo_email' WHERE id = $id;"
        echo "✅ Email atualizado com sucesso (se o ID existir)!"
    fi
    read -p "Pressione [Enter] para voltar ao menu..."
}

# [D]ELETE - Remover Usuário
deletar_usuario() {
    clear
    echo "=== ❌ REMOVER USUÁRIO ==="
    read -p "Digite o ID do usuário a ser deletado: " id

    if [[ ! "$id" =~ ^[0-9]+$ ]]; then
        echo "⚠️  ID inválido."
    else
        executar_cql "DELETE FROM sistema_crud.usuarios WHERE id = $id;"
        echo "✅ Comando de remoção enviado com sucesso!"
    fi
    read -p "Pressione [Enter] para voltar ao menu..."
}

# Fluxo Principal do Script
verificar_conexao
configurar_banco

while true; do
    clear
    echo "======================================"
    echo "     CRUD BASH + APACHE CASSANDRA     "
    echo "======================================"
    echo " [1] Cadastrar Usuário (Create)"
    echo " [2] Listar Usuários (Read)"
    echo " [3] Atualizar Email (Update)"
    echo " [4] Deletar Usuário (Delete)"
    echo " [5] Sair"
    echo "======================================"
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) criar_usuario ;;
        2) listar_usuarios ;;
        3) atualizar_usuario ;;
        4) deletar_usuario ;;
        5) echo "Saindo..."; exit 0 ;;
        *) echo "Opção inválida!"; sleep 1 ;;
    esac
done