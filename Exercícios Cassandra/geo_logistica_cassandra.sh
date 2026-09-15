#!/bin/bash

# Nome do contêiner Docker do Cassandra
CONTAINER_NAME="cassandra_banco2" 

# Garante que a ferramenta 'bc' está instalada no Debian
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

# Inicializa o banco de dados geográfico
configurar_banco() {
    echo "⚙️  Inicializando tabelas de geo-localização..."
    executar_cql "CREATE KEYSPACE IF NOT EXISTS logistica_geo WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};"
    
    # Tabela de rastreamento de motoristas/entregadores
    executar_cql "
    CREATE TABLE IF NOT EXISTS logistica_geo.entregadores (
        id_entregador text PRIMARY KEY,
        nome text,
        latitude double,
        longitude double,
        ultima_atualizacao timestamp
    );"
}

# [C]REATE/UPDATE - Atualizar Posição do Entregador
atualizar_posicao() {
    clear
    echo "=== 📍 ATUALIZAR POSIÇÃO DO ENTREGADOR ==="
    read -p "ID do Entregador (Ex: MOTO_01): " id
    read -p "Nome do Entregador: " nome
    read -p "Latitude Atual (Ex: -23.5505): " lat
    read -p "Longitude Atual (Ex: -46.6333): " lon

    # Validação simples de formato numérico
    if [ -z "$id" ] || [ -z "$nome" ] || [[ ! "$lat" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || [[ ! "$lon" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        echo "⚠️  Coordenadas ou dados inválidos."
        read -p "Pressione [Enter] para continuar..."
        return
    fi

    # Insere ou atualiza no Cassandra
    executar_cql "INSERT INTO logistica_geo.entregadores (id_entregador, nome, latitude, longitude, ultima_atualizacao) 
                  VALUES ('$id', '$nome', $lat, $lon, toTimestamp(now()));"
    
    echo "✅ Posição geográfica registrada com sucesso no Cassandra!"
    read -p "Pressione [Enter] para voltar ao menu..."
}

# [R]EAD + GEOMATH - Calcular Distância e Despachar Entrega
calcular_rota_entrega() {
    clear
    echo "=== 📦 CALCULAR ROTA E DISTÂNCIA DE ENTREGA ==="
    read -p "Digite a Latitude do Cliente (Destino): " cli_lat
    read -p "Digite a Longitude do Cliente (Destino): " cli_lon

    if [[ ! "$cli_lat" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || [[ ! "$cli_lon" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        echo "⚠️  Coordenadas do cliente inválidas."
        read -p "Pressione [Enter] para retornar..."
        return
    fi

    echo ""
    echo "Buscando entregadores disponíveis no Cassandra..."
    echo "--------------------------------------------------------"

    # Busca a lista de entregadores cadastrados
    local raw_data=$(executar_cql "SELECT id_entregador, nome, latitude, longitude FROM logistica_geo.entregadores;")
    
    # Processa os dados linha por linha pulando o cabeçalho do Cassandra
    echo "$raw_data" | awk -F'|' 'NR>3 && $1!="" {print $1 "," $2 "," $3 "," $4}' | while read -r linha; do
        # Divide as colunas vindas do banco
        local ent_id=$(echo "$linha" | cut -d',' -f1 | xargs)
        local ent_nome=$(echo "$linha" | cut -d',' -f2 | xargs)
        local ent_lat=$(echo "$linha" | cut -d',' -f3 | xargs)
        local ent_lon=$(echo "$linha" | cut -d',' -f4 | xargs)

        # LÓGICA MATEMÁTICA: Distância aproximada em KM usando aproximação de graus para km (1 grau ≈ 111.12 km)
        # Teorema de Pitágoras adaptado para coordenadas planas locais: d = sqrt((Δlat)^2 + (Δlon)^2) * 111.12
        local delta_lat=$(echo "scale=6; $ent_lat - $cli_lat" | bc)
        local delta_lon=$(echo "scale=6; $ent_lon - $cli_lon" | bc)
        
        # Quadrado das diferenças
        local quadrado_lat=$(echo "scale=6; $delta_lat * $delta_lat" | bc)
        local quadrado_lon=$(echo "scale=6; $delta_lon * $delta_lon" | bc)
        
        # Distância final calculada com a biblioteca de matemática (-l) para rodar o 'sqrt'
        local distancia_km=$(echo "scale=2; sqrt($quadrado_lat + $quadrado_lon) * 111.12" | bc -l)

        # Lógica de decisão de despacho com base no resultado matemático
        local status_logistico=""
        local tempo_estimado=""
        
        if (( $(echo "$distancia_km < 2.0" | bc -l) )); then
            status_logistico="⚡ EXCELENTE (Perto do cliente)"
            tempo_estimado=$(echo "scale=0; ($distancia_km * 4) + 3" | bc) # Estimativa de minutos
        elif (( $(echo "$distancia_km <= 7.0" | bc -l) )); then
            status_logistico="🚗 MODERADO (Raio padrão de atendimento)"
            tempo_estimado=$(echo "scale=0; ($distancia_km * 3) + 5" | bc)
        else
            status_logistico="⚠️  DISTANTE (Pode haver atrasos)"
            tempo_estimado=$(echo "scale=0; ($distancia_km * 2.5) + 8" | bc)
        fi

        # Exibe o painel logístico calculado para o entregador
        echo "🛵 Entregador: $ent_nome ($ent_id)"
        echo "   📍 Posição no Banco: Lat $ent_lat / Lon $ent_lon"
        echo "   📏 Distância Calculada: $distancia_km KM"
        echo "   ⏱️ Est. Tempo de Chegada: ~$tempo_estimado minutos"
        echo "   📋 Status Logístico: $status_logistico"
        echo "--------------------------------------------------------"
    done

    echo "========================================================"
    read -p "Pressione [Enter] para voltar ao menu..."
}

# [D]ELETE - Remover Entregador da Frota
remover_entregador() {
    clear
    echo "=== ❌ REMOVER ENTREGADOR DA FROTA ==="
    read -p "Digite o ID do entregador (Ex: MOTO_01): " id

    if [ -z "$id" ]; then
        echo "⚠️  ID inválido."
    else
        executar_cql "DELETE FROM logistica_geo.entregadores WHERE id_entregador = '$id';"
        echo "✅ Entregador removido do radar!"
    fi
    read -p "Pressione [Enter] para voltar ao menu..."
}

# Fluxo Principal
verificar_conexao
configurar_banco

while true; do
    clear
    echo "======================================"
    echo "     GEO-LOGISTICS ROUTING SYSTEM     "
    echo "      (Cassandra Cluster Vectors)     "
    echo "======================================"
    echo "1) Atualizar Posição do Entregador (GPS Mock)"
    echo "2) Calcular Distâncias para Entrega (Geo-Math)"
    echo "3) Remover Entregador da Frota"
    echo "4) Sair do Sistema"
    echo "======================================"
    read -p "Escolha o comando tático: " opcao

    case $opcao in
        1) atualizar_posicao ;;
        2) calcular_rota_entrega ;;
        3) remover_entregador ;;
        4) echo "Desligando centrais de rastreamento..."; exit 0 ;;
        *) echo "Opção inválida!"; sleep 1 ;;
    esac
done