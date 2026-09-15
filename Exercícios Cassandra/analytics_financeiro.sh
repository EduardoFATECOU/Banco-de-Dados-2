#!/bin/bash

# Nome do contêiner Docker do Cassandra
CONTAINER_NAME="cassandra_banco2" 

# Garante que a ferramenta 'bc' (calculadora do Linux) está instalada no Debian
if ! command -v bc &> /dev/null; then
    echo "⚙️  Instalando dependência matemática (bc)..."
    sudo apt-get update && sudo apt-get install -y bc
fi

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

# Inicializa o banco de dados financeiro
configurar_banco() {
    echo "⚙️  Inicializando banco de dados quantitativo..."
    executar_cql "CREATE KEYSPACE IF NOT EXISTS mercado_financeiro WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};"
    
    # Tabela estruturada para séries temporais financeiras
    executar_cql "
    CREATE TABLE IF NOT EXISTS mercado_financeiro.historico_precos (
        ticker text,
        data_pregao timestamp,
        abertura double,
        fechamento double,
        maxima double,
        minima double,
        PRIMARY KEY (ticker, data_pregao)
    ) WITH CLUSTERING ORDER BY (data_pregao DESC);"
}

# [C]REATE - Gerador de Pregão (Lógica Matemática de Preços)
simular_pregao() {
    clear
    echo "=== 📈 SIMULAR PREGÃO DIÁRIO DE AÇÃO ==="
    read -p "Digite o código da Ação (Ex: PETR4, VALE3, ITUB4): " ticker
    read -p "Digite o Preço Base/Abertura (Ex: 30.50): " abertura

    if [ -z "$ticker" ] || [[ ! "$abertura" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "⚠️  Dados de entrada inválidos."
        read -p "Pressione [Enter] para continuar..."
        return
    fi

    echo "Calculando variações de mercado para os últimos 5 dias..."
    ticker=$(echo "$ticker" | tr '[:lower:]' '[:upper:]')
    
    # Lógica Matemática: Gerar variações aleatórias controladas para simular dias reais de bolsa
    for dia in {4..0}; do
        # Data retroativa para simular o histórico
        local data_calculada=$(date -d "$dia days ago" "+%Y-%m-%d %H:%M:%S")
        
        # Fórmulas matemáticas via 'bc' para criar Máxima, Mínima e Fechamento realistas
        # Adiciona ou subtrai até 4% aleatoriamente do preço de abertura
        local variacao_fechamento=$(echo "scale=2; ((($RANDOM % 80) - 40) / 1000) * $abertura" | bc)
        local fechamento=$(echo "scale=2; $abertura + $variacao_fechamento" | bc)
        
        # Garante que a máxima é maior que abertura/fechamento e a mínima é menor
        local maxima=$(echo "scale=2; if ($fechamento > $abertura) $fechamento + 0.85 else $abertura + 0.95" | bc)
        local minima=$(echo "scale=2; if ($fechamento < $abertura) $fechamento - 0.75 else $abertura - 0.85" | bc)

        # Insere no Cassandra
        executar_cql "INSERT INTO mercado_financeiro.historico_precos (ticker, data_pregao, abertura, fechamento, maxima, minima) 
                      VALUES ('$ticker', '$data_calculada', $abertura, $fechamento, $maxima, $minima);"
        
        # O preço de abertura do "próximo dia" na simulação vira o fechamento do dia anterior
        abertura=$fechamento
    done

    echo "✅ 5 dias de pregão gerados matematicamente e salvos no Cassandra!"
    read -p "Pressione [Enter] para voltar ao menu..."
}

# [R]EAD + MATH - Relatório de Volatilidade e Médias Móveis
calcular_analise_quantitativa() {
    clear
    echo "=== 📊 ANALYTICS QUANTITATIVO E MATEMÁTICO ==="
    read -p "Digite o Ticker para analisar (Ex: PETR4): " ticker
    ticker=$(echo "$ticker" | tr '[:lower:]' '[:upper:]')

    echo "Buscando dados no Cassandra e processando equações..."
    echo "--------------------------------------------------------"

    # Busca os últimos registros do Cassandra
    local raw_data=$(executar_cql "SELECT abertura, fechamento, maxima, minima FROM mercado_financeiro.historico_precos WHERE ticker='$ticker' LIMIT 5;")
    
    # Extrai as colunas usando processamento de texto
    local fechamentos=$(echo "$raw_data" | awk -F'|' 'NR>3 && $2!="" {print $2}' | xargs)
    local maximas=$(echo "$raw_data" | awk -F'|' 'NR>3 && $3!="" {print $3}' | xargs)
    local minimas=$(echo "$raw_data" | awk -F'|' 'NR>3 && $4!="" {print $4}' | xargs)

    if [ -z "$fechamentos" ]; then
        echo "❌ Nenhum dado encontrado para o ativo $ticker. Rode a simulação primeiro!"
        read -p "Pressione [Enter] para voltar..."
        return
    fi

    # --- CÁLCULO 1: MÉDIA MÓVEL SIMPLES (SMA) ---
    local soma=0
    local qtd=0
    for preco in $fechamentos; do
        soma=$(echo "scale=2; $soma + $preco" | bc)
        qtd=$((qtd + 1))
    done
    local media_movel=$(echo "scale=2; $soma / $qtd" | bc)

    # --- CÁLCULO 2: VOLATILIDADE HISTÓRICA MÉDIA (AMPLITUDE) ---
    local soma_volatilidade=0
    local array_max=($maximas)
    local array_min=($minimas)
    
    for ((i=0; i<qtd; i++)); do
        local max=${array_max[$i]}
        local min=${array_min[$i]}
        # Fórmula matemática da amplitude percentual do dia: ((Máxima - Mínima) / Mínima) * 100
        local amp=$(echo "scale=2; (($max - $min) / $min) * 100" | bc)
        soma_volatilidade=$(echo "scale=2; $soma_volatilidade + $amp" | bc)
    done
    local volatilidade_media=$(echo "scale=2; $soma_volatilidade / $qtd" | bc)

    # --- CÁLCULO 3: RETORNO ACUMULADO DO PERÍODO ---
    local primeiro_fechamento=$(echo $fechamentos | awk '{print $NF}') # Último do texto (mais antigo)
    local ultimo_fechamento=$(echo $fechamentos | awk '{print $1}')    # Primeiro do texto (mais recente)
    # Fórmula: ((Último / Primeiro) - 1) * 100
    local retorno_periodo=$(echo "scale=2; (($ultimo_fechamento / $primeiro_fechamento) - 1) * 100" | bc)

    # Exibição dos Indicadores Matemáticos
    echo "📊 INDICADORES MATEMÁTICOS PARA: $ticker (Base: $qtd Pregões)"
    echo "--------------------------------------------------------"
    echo "📈 Média Móvel Simples (SMA-5): R$ $media_movel"
    echo "⚡ Volatilidade Média Diária:   $volatilidade_media%"
    echo "💰 Retorno Líquido do Período:  $retorno_periodo%"
    echo "--------------------------------------------------------"
    echo "Status de Risco:"
    if (( $(echo "$volatilidade_media > 4.0" | bc -l) )); then
        echo "⚠️  ALTO RISCO: Ativo com oscilação severa de preços."
    else
        echo "✅ RISCO CONTROLADO: Ativo com comportamento estável."
    fi
    echo "========================================================"
    read -p "Pressione [Enter] para voltar ao menu..."
}

# [D]ELETE - Limpar Histórico do Ativo
limpar_ativo() {
    clear
    echo "=== ❌ APAGAR HISTÓRICO DE ATIVO ==="
    read -p "Digite o Ticker que deseja deletar (Ex: PETR4): " ticker
    ticker=$(echo "$ticker" | tr '[:lower:]' '[:upper:]')

    if [ -z "$ticker" ]; then
        echo "⚠️  Ativo inválido."
    else
        executar_cql "DELETE FROM mercado_financeiro.historico_precos WHERE ticker = '$ticker';"
        echo "✅ Todo o histórico de $ticker foi removido do Cassandra!"
    fi
    read -p "Pressione [Enter] para voltar ao menu..."
}

# Fluxo Principal
verificar_conexao
configurar_banco

while true; do
    clear
    echo "======================================"
    echo "    QUANT TRADING ANALYTICS SYSTEM    "
    echo "      (Cassandra Matrix & Math)       "
    echo "======================================"
    echo "1) Simular 5 Dias de Mercado (Inserir com Lógica)"
    echo "2) Rodar Análise Matemática (Média, Volatilidade)"
    echo "3) Deletar Histórico de um Ativo"
    echo "4) Sair do Sistema"
    echo "======================================"
    read -p "Escolha a operação: " opcao

    case $opcao in
        1) simular_pregao ;;
        2) calcular_analise_quantitativa ;;
        3) limpar_ativo ;;
        4) echo "Fechando terminal financeiro..."; exit 0 ;;
        *) echo "Opção inválida!"; sleep 1 ;;
    esac
done