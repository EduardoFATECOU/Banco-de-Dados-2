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

# Inicializa a estrutura de Big Data no Cassandra
configurar_banco() {
    echo "⚙️  Preparando infraestrutura de Big Data para IoT..."
    executar_cql "CREATE KEYSPACE IF NOT EXISTS fabrica_iot WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};"
    
    # Criando tabela otimizada para séries temporais (Time-Series Data)
    executar_cql "
    CREATE TABLE IF NOT EXISTS fabrica_iot.telemetria (
        sensor_id text,
        horario timestamp,
        temperatura double,
        pressao int,
        PRIMARY KEY (sensor_id, horario)
    ) WITH CLUSTERING ORDER BY (horario DESC);"
}

# GERADOR EM MASSA (Loop de Alta Velocidade)
iniciar_gerador_massa() {
    clear
    echo "====================================================="
    echo "       🚀 INICIANDO GERADOR DE CARGA EM LOOP         "
    echo "====================================================="
    echo " O script vai inundar o Cassandra com centenas de dados."
    echo " Pressione [CTRL + C] a qualquer momento para PARAR a carga."
    echo "====================================================="
    echo "Gerando registros... Aguarde 3 segundos para iniciar..."
    sleep 3

    local total_inserido=0
    
    # Loop infinito de alta velocidade
    while true; do
        local cql_batch=""
        
        # Agrupa 50 inserções em um lote rápido para o Cassandra processar em milissegundos
        for i in {1..50}; do
            # Sorteia sensores de 1 a 5
            local sensor="SENSOR_0$(( (RANDOM % 5) + 1 ))"
            # Sorteia temperaturas realistas entre 20.0 e 99.9 graus
            local temp="$(( (RANDOM % 80) + 20 )).$(( RANDOM % 10 ))"
            # Sorteia pressões entre 90 e 150 PSI
            local pressao=$(( (RANDOM % 60) + 90 ))
            
            # Constrói o comando de inserção usando toTimestamp(now()) nativo do Cassandra
            cql_batch+="INSERT INTO fabrica_iot.telemetria (sensor_id, horario, temperatura, pressao) VALUES ('$sensor', toTimestamp(now()), $temp, $pressao); "
        done
        
        # Dispara o bloco de comandos de uma vez só para o Docker
        executar_cql "$cql_batch"
        
        total_inserido=$((total_inserido + 50))
        echo "⚡ [+] Mais 50 registros enviados para o Cassandra! Total enviado até agora: $total_inserido"
    done
}

# AUDITORIA E LEITURA (Métricas em Tempo Real)
ver_metricas_analytics() {
    clear
    echo "====================================================="
    echo "      📊 ANALYTICS & MÉDRIAS DO CASSANDRA            "
    echo "====================================================="
    echo "Buscando os dados agregados diretamente do banco..."
    echo "-----------------------------------------------------"
    
    # Conta o volume total acumulado no Cassandra
    local count_resultado=$(executar_cql "SELECT count(*) FROM fabrica_iot.telemetria LIMIT 100000;")
    local total_linhas=$(echo "$count_resultado" | awk 'NR==4 {print $1}' | xargs)

    if [ -z "$total_linhas" ] || [ "$total_linhas" == "0" ]; then
        echo "❌ O banco de dados está vazio. Vá ao menu e rode o Gerador de Carga primeiro!"
    else
        echo "📈 Total de registros encontrados no banco: $total_linhas"
        echo "-----------------------------------------------------"
        echo "Últimas 5 leituras mais recentes registradas:"
        executar_cql "SELECT sensor_id, horario, temperatura, pressao FROM fabrica_iot.telemetria LIMIT 5;"
    fi
    echo "====================================================="
    read -p "Pressione [Enter] para voltar ao menu..."
}

# TRUNCATE (Limpar tudo para novos testes)
limpar_massa_dados() {
    clear
    echo "=== 🧹 LIMPEZA DE DADOS ==="
    read -p "Tem certeza que deseja apagar milhões de registros da tabela? (s/n): " confirma
    if [ "$confirma" == "s" ] || [ "$confirma" == "S" ]; then
        echo "Truncando tabela no Cassandra..."
        executar_cql "TRUNCATE fabrica_iot.telemetria;"
        echo "✅ Tabela limpa e pronta para novos testes de estresse!"
    else
        echo "Operação cancelada."
    fi
    sleep 2
}

# Fluxo Principal do Script
verificar_conexao
configurar_banco

while true; do
    clear
    echo "======================================"
    echo "   STRESS TEST & BIG DATA CASSANDRA   "
    echo "======================================"
    echo "1) Iniciar Inundação de Dados (Loop em Massa)"
    echo "2) Ver Métricas e Contador (Analytics)"
    echo "3) Resetar Banco (Limpar Registros)"
    echo "4) Sair do Sistema"
    echo "======================================"
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) iniciar_gerador_massa ;;
        2) ver_metricas_analytics ;;
        3) limpar_massa_dados ;;
        4) echo "Saindo..."; exit 0 ;;
        *) echo "Opção inválida!"; sleep 1 ;;
    esac
done