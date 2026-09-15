#!/bin/bash

# Nome do contêiner Docker do Cassandra
CONTAINER_NAME="cassandra_banco2" 

# Função para testar a conexão com o contêiner
verificar_conexao() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "❌ ERRO: O contêiner '$CONTAINER_NAME' não está rodando."
        read -p "Digite o nome do contêiner do Cassandra: " CONTAINER_NAME
        if [ -z "$CONTAINER_NAME" ]; then exit 1; fi
    fi
}

# Executa comandos CQL dentro do contêiner
executar_cql() {
    local cql_query="$1"
    docker exec -i "$CONTAINER_NAME" cqlsh -e "$cql_query"
}

# Inicializa o banco de dados de espionagem
configurar_banco() {
    echo "⚙️  Ativando protocolos de segurança..."
    executar_cql "CREATE KEYSPACE IF NOT EXISTS qg_secreto WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};"
    executar_cql "CREATE TABLE IF NOT EXISTS qg_secreto.mensagens (id int PRIMARY KEY, agente text, conteudo text);"
}

# [C]REATE - Enviar Mensagem com Autodestruição (TTL)
enviar_mensagem() {
    clear
    echo "=== 📨 ENVIAR MENSAGEM CRIPTOGRAFADA ==="
    read -p "Digite o código numérico da mensagem (ID): " id
    read -p "Codinome do Agente: " agente
    read -p "Texto Secreto da Mensagem: " texto
    read -p "Tempo para autodestruição (em segundos): " segundos

    if [[ ! "$id" =~ ^[0-9]+$ ]] || [[ ! "$segundos" =~ ^[0-9]+$ ]] || [ -z "$agente" ] || [ -z "$texto" ]; then
        echo "⚠️  Dados inválidos. Tente novamente."
    else
        # Criptografa o texto em Base64 para simular uma transmissão secreta
        conteudo_cripto=$(echo -n "$texto" | base64)
        
        # O pulo do gato está no 'USING TTL' do Cassandra!
        executar_cql "INSERT INTO qg_secreto.mensagens (id, agente, conteudo) VALUES ($id, '$agente', '$conteudo_cripto') USING TTL $segundos;"
        echo "========================================="
        echo "✅ Mensagem enviador com sucesso!"
        echo "⚠️  Esta mensagem se autodestruirá em $segundos segundos."
    fi
    read -p "Pressione [Enter] para voltar ao menu..."
}

# [R]EAD - Ler e Descriptografar Mensagem
ler_mensagem() {
    clear
    echo "=== 🔎 INTERCEPTAR MENSAGEM DO BANCO ==="
    read -p "Digite o ID da mensagem que deseja ler: " id

    if [[ ! "$id" =~ ^[0-9]+$ ]]; then
        echo "⚠️  ID inválido."
    else
        # Busca a mensagem do Cassandra e traz também o tempo restante de vida (TTL) dela
        resultado=$(executar_cql "SELECT agente, conteudo, ttl(conteudo) FROM qg_secreto.mensagens WHERE id = $id;")
        
        # Filtra o conteúdo criptografado e o agente da saída formatada do Cassandra
        agente_nome=$(echo "$resultado" | awk -F'|' 'NR==4 {print $1}' | xargs)
        conteudo_base64=$(echo "$resultado" | awk -F'|' 'NR==4 {print $2}' | xargs)
        tempo_restante=$(echo "$resultado" | awk -F'|' 'NR==4 {print $3}' | xargs)

        if [ -z "$conteudo_base64" ] || [ "$conteudo_base64" == "null" ]; then
            echo "❌ Nenhuma mensagem encontrada. (Ou ela já se autodestruiu!)"
        else
            # Descriptografa o conteúdo original
            texto_original=$(echo -n "$conteudo_base64" | base64 --decode)
            echo "-----------------------------------------"
            echo "👤 Enviado por Agente: $agente_nome"
            echo "🔓 Mensagem Decodificada: $texto_original"
            echo "⏳ Tempo restante de vida no Cassandra: $tempo_restante segundos"
            echo "-----------------------------------------"
        fi
    fi
    read -p "Pressione [Enter] para voltar ao menu..."
}

# [R]EAD ALL - Ver Caixa de Mensagens Ativas
ver_caixa_entrada() {
    clear
    echo "=== 📬 CAIXA DE MENSAGENS ATIVAS NO BANCO ==="
    echo "Se a lista estiver vazia, o tempo expirou e o Cassandra apagou os registros sozinho!"
    echo "-----------------------------------------"
    executar_cql "SELECT id, agente, conteudo FROM qg_secreto.mensagens;"
    echo "========================================"
    read -p "Pressione [Enter] para voltar ao menu..."
}

# [D]ELETE - Abortar Missão (Apagar manualmente se necessário)
abortar_mensagem() {
    clear
    echo "=== 💥 APAGAR MENSAGEM MANUALMENTE (ABORTAR) ==="
    read -p "Digite o ID da mensagem para queima imediata: " id

    if [[ ! "$id" =~ ^[0-9]+$ ]]; then
        echo "⚠️  ID inválido."
    else
        executar_cql "DELETE FROM qg_secreto.mensagens WHERE id = $id;"
        echo "💥 Mensagem eliminada com sucesso!"
    fi
    read -p "Pressione [Enter] para voltar ao menu..."
}

# Fluxo Principal do Script
verificar_conexao
configurar_banco

while true; do
    clear
    echo "======================================"
    echo "     SISTEMA DE MENSAGENS SECRETAS    "
    echo "      (Cassandra TTL Technology)      "
    echo "======================================"
    echo "1) Enviar Mensagem Criptografada (Create com TTL)"
    echo "2) Ler e Decodificar Mensagem (Read)"
    echo "3) Listar Todas Ativas na Caixa (Read All)"
    echo "4) Abortar e Queimar Mensagem (Delete)"
    echo "5) Fechar Terminal"
    echo "======================================"
    read -p "Escolha o protocolo: " opcao

    case $opcao in
        1) enviar_mensagem ;;
        2) ler_mensagem ;;
        3) ver_caixa_entrada ;;
        4) abortar_mensagem ;;
        5) echo "Encerrando sessão..."; exit 0 ;;
        *) echo "Opção inválida!"; sleep 1 ;;
    esac
done