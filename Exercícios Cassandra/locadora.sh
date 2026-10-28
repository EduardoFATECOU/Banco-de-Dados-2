#!/usr/bin/env bash
# =============================================================================
#  Sistema de Locadora de Veículos  —  Cassandra + dialog
# -----------------------------------------------------------------------------
#  Correções em relação à versão original:
#    * erros do cqlsh NÃO são mais escondidos (fim do 2>/dev/null):
#      toda escrita confere o resultado antes de dizer "sucesso"
#    * todo valor digitado é escapado antes de entrar na CQL (apóstrofo /
#      tentativa de injeção)
#    * campos obrigatórios são validados um a um (formulário vazio não passa)
#    * INSERT usa IF NOT EXISTS e UPDATE/DELETE usam IF EXISTS (LWT),
#      conferindo a coluna [applied] — nada de "atualizado!" em id inexistente
#    * confirmação antes de excluir + trap para não deixar o terminal sujo
#    * *novo*: listagem de aluguéis com nome do cliente e modelo/marca do veículo
#    * *novo*: opção "Excluir Aluguel"
#
#  Requisitos: bash 4+, dialog, docker, coreutils (date).
#
#  Uso:
#      chmod +x locadora.sh && ./locadora.sh
#      CONTAINER_NAME=cassandra-locadora ./locadora.sh
#
#  Modelo de dados (o CREATE abaixo é idempotente):
#      clientes   (id PK, nome, telefone)
#      automoveis (placa PK, modelo, marca)
#      alugueis   (id PK, id_cliente, nome_cliente, placa_veiculo,
#                  modelo_veiculo, marca_veiculo, valor, pago,
#                  data_retirada, data_devolucao)
#
#  Por que os nomes estão duplicados em alugueis?
#  Cassandra não faz JOIN. O nome do cliente e o modelo do veículo são copiados
#  no momento do aluguel (desnormalização). Na listagem o script usa o nome
#  ATUAL de clientes/automoveis quando o registro ainda existe e, se o cliente
#  foi excluído, mostra o nome gravado no aluguel — preservando o histórico.
# =============================================================================

CONTAINER_NAME="${CONTAINER_NAME:-seu-container-cassandra}"
KEYSPACE="${KEYSPACE:-locadora}"

# Separador de campos usado internamente (0x1F). Não é espaço nem tab, então
# campos vazios não se "colapsam" na leitura com `read`.
SEP=$'\x1f'

TMP="$(mktemp -d "${TMPDIR:-/tmp}/locadora.XXXXXX")" || {
    echo "Erro: não foi possível criar o diretório temporário." >&2
    exit 1
}
trap 'rm -rf "$TMP"' EXIT
trap 'clear; exit 130' INT TERM

# Largura útil para as caixas de texto (nunca maior que 110 colunas).
LARGURA=$(tput cols 2>/dev/null) || LARGURA=""
[[ "$LARGURA" =~ ^[0-9]+$ ]] || LARGURA=100
(( LARGURA > 110 )) && LARGURA=110
(( LARGURA < 62 )) && LARGURA=62


# =============================================================================
#  1. Utilidades
# =============================================================================

# Remove espaços em branco das pontas.
trim() {
    local s="${1-}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Verdadeiro se a string for vazia ou só espaços.
vazio() {
    local s="${1-}"
    [[ "${s//[[:space:]]/}" == "" ]]
}

# Escapa aspas simples para uso seguro dentro de uma string CQL.
# 'O'Brien' -> 'O''Brien'
esc() {
    printf '%s' "${1-}" | sed "s/'/''/g"
}

# Data válida no formato AAAA-MM-DD (rejeita 2026-02-31, etc.).
validar_data() {
    local d="${1-}" normalizada
    [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
    normalizada=$(date -d "$d" +%F 2>/dev/null) || return 1
    [[ "$normalizada" == "$d" ]]
}

# Valor monetário: números com até 2 casas decimais.
validar_valor() {
    [[ "${1-}" =~ ^[0-9]{1,9}([.][0-9]{1,2})?$ ]]
}

# Primeiro campo de uma linha SEP.
primeiro_campo() {
    local p
    IFS="$SEP" read -r p _ <<< "${1-}"
    printf '%s' "$p"
}


# =============================================================================
#  2. Caixas de diálogo
# =============================================================================

# Mostra um texto: caixa simples quando é curto, caixa com rolagem quando é
# longo (erro do cqlsh pode ter dezenas de linhas).
mostrar() {
    local texto="${1-}" titulo="${2:-Informação}" linhas colunas
    linhas=$(printf '%s\n' "$texto" | wc -l)
    colunas=$(printf '%s\n' "$texto" | awk '{ if (length($0) > m) m = length($0) } END { print m + 4 }')
    if (( linhas > 16 || colunas > 78 )); then
        printf '%s\n' "$texto" > "$TMP/mensagem.txt"
        dialog --title "$titulo" --textbox "$TMP/mensagem.txt" 24 "$LARGURA"
    else
        dialog --title "$titulo" --msgbox "$texto" 0 0
    fi
}

msg()  { mostrar "${1-}" "Informação"; }
erro() { mostrar "${1-}" "Erro"; }

caixa_texto() {
    printf '%s\n' "${1-}" > "$TMP/lista.txt"
    dialog --title "${2:-Lista}" --textbox "$TMP/lista.txt" 24 "$LARGURA"
}


# =============================================================================
#  3. Camada Cassandra
# =============================================================================

# COLUMNS=1000 evita que o cqlsh quebre células longas em várias linhas, o que
# bagunçaria a leitura da saída.
cql_raw() {
    docker exec -e COLUMNS=1000 "$CONTAINER_NAME" cqlsh -e "$1" 2>&1
}

# Executa dentro do keyspace da aplicação.
cql() {
    cql_raw "USE $KEYSPACE; $1"
}

# Converte a tabela de texto do cqlsh em linhas separadas por $SEP.
# Em caso de falha, imprime a mensagem de erro real e retorna 1.
tsv() {
    local consulta="$1" bruto
    bruto=$(cql "$consulta") || { printf '%s' "$bruto"; return 1; }

    printf '%s\n' "$bruto" | awk -v sep="$SEP" '
        function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s); return s }
        BEGIN { cabecalho = 1 }
        /^[ \t]*$/          { next }
        /^[ \t]*\(/         { next }   # linha "(N rows)"
        /^[Ww]arning/       { next }
        /^-{2,}/            { next }   # linha de traços
        /^[ \t]*\[json\]/   { next }
        {
            if (cabecalho) { cabecalho = 0; next }
            n = split($0, campo, "[|]")
            linha = trim(campo[1])
            for (i = 2; i <= n; i++) linha = linha sep trim(campo[i])
            print linha
        }'
}

# Executa uma escrita com LWT (IF NOT EXISTS / IF EXISTS) e confere [applied].
#   $1 = consulta   $2 = mensagem de sucesso   $3 = mensagem quando não aplicou
gravar() {
    local consulta="$1" msg_ok="$2" msg_nao="$3" saida
    if ! saida=$(tsv "$consulta"); then
        erro "A operação falhou no banco de dados:

$saida"
        return 1
    fi
    if [ "$(primeiro_campo "$saida")" = "True" ]; then
        msg "$msg_ok"
        return 0
    fi
    erro "$msg_nao"
    return 1
}


# =============================================================================
#  4. Ambiente: docker, dialog e container
# =============================================================================

requisitos() {
    if ! command -v dialog >/dev/null 2>&1; then
        echo "O programa 'dialog' não está instalado." >&2
        echo "Debian/Ubuntu: sudo apt install dialog   |   Fedora: sudo dnf install dialog" >&2
        exit 1
    fi
    if ! command -v docker >/dev/null 2>&1; then
        echo "O comando 'docker' não foi encontrado no PATH." >&2
        exit 1
    fi
    if ! docker info >/dev/null 2>&1; then
        erro "O Docker está instalado, mas o daemon não responde.

Verifique se o Docker está iniciado e se o seu usuário tem permissão para
usá-lo (grupo 'docker')."
        exit 1
    fi
}

# Descobre o container do Cassandra: usa CONTAINER_NAME ou procura entre os
# containers em execução. Evita o diagnóstico errado de "container não roda".
resolver_container() {
    if docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
        return 0
    fi

    local candidatos n c escolha i
    candidatos=$(docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null |
        awk 'tolower($0) ~ /cassandra/ { print $1 }' | sort -u)
    n=$(printf '%s\n' "$candidatos" | grep -c .)
    (( n > 0 )) || n=0

    if (( n == 0 )); then
        local rodando
        rodando=$(docker ps --format '{{.Names}} ({{.Image}})' | head -n 15)
        erro "O container '$CONTAINER_NAME' não está em execução.

Containers em execução agora:
${rodando:-(nenhum)}

Inicie o Cassandra (ex.: docker start <container>) ou ajuste a variável
CONTAINER_NAME no topo deste script."
        exit 1
    elif (( n == 1 )); then
        CONTAINER_NAME="$candidatos"
    else
        local opcoes=()
        i=1
        while IFS= read -r c; do
            [ -z "$c" ] && continue
            opcoes+=("$i" "$c")
            i=$((i + 1))
        done <<< "$candidatos"
        escolha=$(dialog --stdout --menu "Escolha o container do Cassandra" 18 62 10 "${opcoes[@]}") || exit 1
        CONTAINER_NAME=$(printf '%s\n' "$candidatos" | sed -n "${escolha}p")
    fi
}

# O cqlsh pode ainda estar subindo junto com o container.
aguardar_cqlsh() {
    local tentativa
    dialog --infobox "Conectando ao Cassandra (container '$CONTAINER_NAME')..." 4 66
    for tentativa in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        if cql_raw "SELECT release_version FROM system.local;" >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    erro "O Cassandra não respondeu em 30 segundos.

Container: $CONTAINER_NAME

Verifique com:  docker logs --tail 50 $CONTAINER_NAME"
    exit 1
}

# Acrescenta uma coluna somente se ela ainda não existir.
garantir_coluna() {
    local tabela="$1" coluna="$2" tipo="$3" existe
    existe=$(tsv "SELECT column_name FROM system_schema.columns
        WHERE keyspace_name='$KEYSPACE' AND table_name='$tabela' AND column_name='$coluna';")
    if [ -z "$existe" ]; then
        cql "ALTER TABLE $tabela ADD $coluna $tipo;" >/dev/null
    fi
}

init_database() {
    local saida ddl tabelas=(
        "CREATE TABLE IF NOT EXISTS clientes (id text PRIMARY KEY, nome text, telefone text);"
        "CREATE TABLE IF NOT EXISTS automoveis (placa text PRIMARY KEY, modelo text, marca text);"
        "CREATE TABLE IF NOT EXISTS alugueis (id text PRIMARY KEY, id_cliente text, nome_cliente text, placa_veiculo text, modelo_veiculo text, marca_veiculo text, valor decimal, pago boolean, data_retirada date, data_devolucao date);"
    )

    dialog --infobox "Verificando a estrutura do banco..." 4 60

    if ! saida=$(cql_raw "CREATE KEYSPACE IF NOT EXISTS $KEYSPACE WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};"); then
        erro "Falha ao criar o keyspace '$KEYSPACE':

$saida"
        exit 1
    fi

    for ddl in "${tabelas[@]}"; do
        if ! saida=$(cql "$ddl"); then
            erro "Falha ao criar a tabela:

$saida"
            exit 1
        fi
    done

    # Bancos criados pela versão antiga do script não têm as colunas
    # desnormalizadas (e podem ter 'valor double' em vez de 'decimal' — o
    # CREATE IF NOT EXISTS não altera tipos, mas a aplicação funciona igual).
    garantir_coluna alugueis nome_cliente text
    garantir_coluna alugueis modelo_veiculo text
    garantir_coluna alugueis marca_veiculo text
}


# =============================================================================
#  5. Clientes
# =============================================================================

menu_clientes() {
    local opcao dados cpf nome tel atual nome_atual tel_atual bruto rc total n_alug aviso

    while true; do
        opcao=$(dialog --stdout --menu "Gerenciamento de Clientes" 15 50 5 \
            1 "Cadastrar Cliente" \
            2 "Listar Clientes" \
            3 "Atualizar Cliente" \
            4 "Excluir Cliente" \
            0 "Voltar") || return

        case "$opcao" in
            1)
                dados=$(dialog --stdout --form "Cadastrar Cliente" 12 50 0 \
                    "CPF/ID:"   1 1 "" 1 15 20 0 \
                    "Nome:"     2 1 "" 2 15 30 0 \
                    "Telefone:" 3 1 "" 3 15 20 0) || continue

                cpf=$(trim "$(printf '%s\n' "$dados" | sed -n '1p')")
                nome=$(trim "$(printf '%s\n' "$dados" | sed -n '2p')")
                tel=$(trim "$(printf '%s\n' "$dados" | sed -n '3p')")

                if vazio "$cpf";  then erro "O CPF/ID é obrigatório.";  continue; fi
                if vazio "$nome"; then erro "O nome é obrigatório.";    continue; fi

                gravar "INSERT INTO clientes (id, nome, telefone) VALUES ('$(esc "$cpf")', '$(esc "$nome")', '$(esc "$tel")') IF NOT EXISTS;" \
                    "Cliente cadastrado com sucesso!" \
                    "Já existe um cliente com o ID '$cpf'.

Use a opção \"Atualizar Cliente\" se quiser alterar os dados."
                ;;

            2)
                bruto=$(cql "SELECT id, nome, telefone FROM clientes;"); rc=$?
                if (( rc != 0 )); then
                    erro "Falha ao listar clientes:

$bruto"
                    continue
                fi
                total=$(tsv "SELECT COUNT(*) FROM clientes;")
                caixa_texto "Clientes cadastrados: ${total:-0}

$bruto" "Lista de Clientes"
                ;;

            3)
                cpf=$(dialog --stdout --inputbox "Digite o CPF/ID do cliente para atualizar:" 8 50) || continue
                cpf=$(trim "$cpf")
                if vazio "$cpf"; then erro "Informe o CPF/ID."; continue; fi

                atual=$(tsv "SELECT nome, telefone FROM clientes WHERE id='$(esc "$cpf")';")
                if [ -z "$atual" ]; then
                    erro "Cliente '$cpf' não encontrado."
                    continue
                fi

                IFS="$SEP" read -r nome_atual tel_atual <<< "$atual"
                [ "$nome_atual" = "null" ] && nome_atual=""
                [ "$tel_atual"  = "null" ] && tel_atual=""

                dados=$(dialog --stdout --form "Atualizar Cliente $cpf" 12 55 0 \
                    "Nome:"     1 1 "$nome_atual" 1 15 30 0 \
                    "Telefone:" 2 1 "$tel_atual"  2 15 20 0) || continue

                nome=$(trim "$(printf '%s\n' "$dados" | sed -n '1p')")
                tel=$(trim "$(printf '%s\n' "$dados" | sed -n '2p')")
                if vazio "$nome"; then erro "O nome não pode ficar vazio."; continue; fi

                gravar "UPDATE clientes SET nome='$(esc "$nome")', telefone='$(esc "$tel")' WHERE id='$(esc "$cpf")' IF EXISTS;" \
                    "Cliente atualizado!" \
                    "O cliente '$cpf' não existe mais."
                ;;

            4)
                cpf=$(dialog --stdout --inputbox "Digite o CPF/ID do cliente para EXCLUIR:" 8 50) || continue
                cpf=$(trim "$cpf")
                if vazio "$cpf"; then erro "Informe o CPF/ID."; continue; fi

                atual=$(tsv "SELECT nome FROM clientes WHERE id='$(esc "$cpf")';")
                if [ -z "$atual" ]; then
                    erro "Cliente '$cpf' não encontrado."
                    continue
                fi

                # ALLOW FILTERING: varredura completa — aceitável neste volume.
                n_alug=$(tsv "SELECT COUNT(*) FROM alugueis WHERE id_cliente='$(esc "$cpf")' ALLOW FILTERING;")
                aviso="Excluir o cliente '$atual' (ID $cpf)?"
                if [[ "$n_alug" =~ ^[0-9]+$ ]] && (( n_alug > 0 )); then
                    aviso="$aviso

Atenção: existem $n_alug aluguel(is) vinculado(s) a este cliente.
O histórico dos aluguéis será mantido."
                fi

                dialog --title "Confirmar exclusão" --yesno "$aviso" 0 0 || continue

                gravar "DELETE FROM clientes WHERE id='$(esc "$cpf")' IF EXISTS;" \
                    "Cliente removido!" \
                    "O cliente '$cpf' não existe mais."
                ;;

            *) return ;;
        esac
    done
}


# =============================================================================
#  6. Automóveis
# =============================================================================

menu_automoveis() {
    local opcao dados placa modelo marca atual modelo_atual marca_atual bruto rc total n_alug aviso

    while true; do
        opcao=$(dialog --stdout --menu "Gerenciamento de Automóveis" 15 50 5 \
            1 "Cadastrar Veículo" \
            2 "Listar Veículos" \
            3 "Atualizar Veículo" \
            4 "Excluir Veículo" \
            0 "Voltar") || return

        case "$opcao" in
            1)
                dados=$(dialog --stdout --form "Cadastrar Automóvel" 12 50 0 \
                    "Placa:"  1 1 "" 1 15 15 0 \
                    "Modelo:" 2 1 "" 2 15 25 0 \
                    "Marca:"  3 1 "" 3 15 25 0) || continue

                placa=$(trim "$(printf '%s\n' "$dados" | sed -n '1p')")
                modelo=$(trim "$(printf '%s\n' "$dados" | sed -n '2p')")
                marca=$(trim "$(printf '%s\n' "$dados" | sed -n '3p')")

                if vazio "$placa";  then erro "A placa é obrigatória.";  continue; fi
                if vazio "$modelo"; then erro "O modelo é obrigatório."; continue; fi

                gravar "INSERT INTO automoveis (placa, modelo, marca) VALUES ('$(esc "$placa")', '$(esc "$modelo")', '$(esc "$marca")') IF NOT EXISTS;" \
                    "Automóvel cadastrado!" \
                    "Já existe um veículo com a placa '$placa'.

Use a opção \"Atualizar Veículo\" se quiser alterar os dados."
                ;;

            2)
                bruto=$(cql "SELECT placa, modelo, marca FROM automoveis;"); rc=$?
                if (( rc != 0 )); then
                    erro "Falha ao listar veículos:

$bruto"
                    continue
                fi
                total=$(tsv "SELECT COUNT(*) FROM automoveis;")
                caixa_texto "Veículos cadastrados: ${total:-0}

$bruto" "Lista de Veículos"
                ;;

            3)
                placa=$(dialog --stdout --inputbox "Digite a placa do veículo para atualizar:" 8 50) || continue
                placa=$(trim "$placa")
                if vazio "$placa"; then erro "Informe a placa."; continue; fi

                atual=$(tsv "SELECT modelo, marca FROM automoveis WHERE placa='$(esc "$placa")';")
                if [ -z "$atual" ]; then
                    erro "Veículo '$placa' não encontrado."
                    continue
                fi

                IFS="$SEP" read -r modelo_atual marca_atual <<< "$atual"
                [ "$modelo_atual" = "null" ] && modelo_atual=""
                [ "$marca_atual"  = "null" ] && marca_atual=""

                dados=$(dialog --stdout --form "Atualizar Automóvel $placa" 12 55 0 \
                    "Modelo:" 1 1 "$modelo_atual" 1 15 25 0 \
                    "Marca:"  2 1 "$marca_atual"  2 15 25 0) || continue

                modelo=$(trim "$(printf '%s\n' "$dados" | sed -n '1p')")
                marca=$(trim "$(printf '%s\n' "$dados" | sed -n '2p')")
                if vazio "$modelo"; then erro "O modelo não pode ficar vazio."; continue; fi

                gravar "UPDATE automoveis SET modelo='$(esc "$modelo")', marca='$(esc "$marca")' WHERE placa='$(esc "$placa")' IF EXISTS;" \
                    "Automóvel atualizado!" \
                    "O veículo '$placa' não existe mais."
                ;;

            4)
                placa=$(dialog --stdout --inputbox "Digite a placa do veículo para EXCLUIR:" 8 50) || continue
                placa=$(trim "$placa")
                if vazio "$placa"; then erro "Informe a placa."; continue; fi

                atual=$(tsv "SELECT modelo, marca FROM automoveis WHERE placa='$(esc "$placa")';")
                if [ -z "$atual" ]; then
                    erro "Veículo '$placa' não encontrado."
                    continue
                fi

                n_alug=$(tsv "SELECT COUNT(*) FROM alugueis WHERE placa_veiculo='$(esc "$placa")' ALLOW FILTERING;")
                aviso="Excluir o veículo '$placa' (${atual//"$SEP"/ })?"
                if [[ "$n_alug" =~ ^[0-9]+$ ]] && (( n_alug > 0 )); then
                    aviso="$aviso

Atenção: existem $n_alug aluguel(is) registrados com esta placa.
O histórico dos aluguéis será mantido."
                fi

                dialog --title "Confirmar exclusão" --yesno "$aviso" 0 0 || continue

                gravar "DELETE FROM automoveis WHERE placa='$(esc "$placa")' IF EXISTS;" \
                    "Veículo removido!" \
                    "O veículo '$placa' não existe mais."
                ;;

            *) return ;;
        esac
    done
}


# =============================================================================
#  7. Aluguéis
# =============================================================================

# Monta a lista com nome do cliente e descrição do veículo.
listar_alugueis() {
    local bruto rc total pend soma
    bruto=$(tsv "SELECT id, id_cliente, nome_cliente, placa_veiculo, modelo_veiculo, marca_veiculo, valor, pago, data_retirada, data_devolucao FROM alugueis;"); rc=$?
    if (( rc != 0 )); then
        erro "Falha ao listar aluguéis:

$bruto"
        return
    fi
    if [ -z "$bruto" ]; then
        caixa_texto "Nenhum aluguel registrado." "Histórico de Aluguéis"
        return
    fi

    # O Cassandra não faz JOIN: resolvemos nome/modelo aqui, com dois SELECTs.
    declare -A nomes veiculos
    local cid cnome placa modelo marca
    while IFS="$SEP" read -r cid cnome; do
        [ -z "$cid" ] && continue
        [ "$cnome" = "null" ] && cnome=""
        nomes["$cid"]="$cnome"
    done < <(tsv "SELECT id, nome FROM clientes;" 2>/dev/null)

    while IFS="$SEP" read -r placa modelo marca; do
        [ -z "$placa" ] && continue
        [ "$modelo" = "null" ] && modelo=""
        [ "$marca"  = "null" ] && marca=""
        veiculos["$placa"]="${modelo}${marca:+ / $marca}"
    done < <(tsv "SELECT placa, modelo, marca FROM automoveis;" 2>/dev/null)

    {
        printf '%-10s %-24s %-22s %-10s %9s %-4s %-11s %-11s\n' \
            "ID" "CLIENTE" "VEÍCULO" "PLACA" "VALOR" "PAGO" "RETIRADA" "DEVOLUÇÃO"
        printf '%s\n' "---------- ------------------------ ---------------------- ---------- --------- ---- ----------- -----------"

        while IFS="$SEP" read -r aid acid anome aplaca amodelo amarca avalor apago aret adev; do
            [ -z "$aid" ] && continue

            local ncli vdesc pg
            # nome atual do cliente; se ele foi excluído, usa o nome gravado
            ncli="${nomes[$acid]:-$anome}"
            [ "$ncli" = "null" ] && ncli=""
            [ -z "$ncli" ] && ncli="(não encontrado)"

            vdesc="${veiculos[$aplaca]:-}"
            if [ -z "$vdesc" ]; then
                local m="$amodelo" ma="$amarca"
                [ "$m"  = "null" ] && m=""
                [ "$ma" = "null" ] && ma=""
                vdesc="${m}${ma:+ / $ma}"
            fi
            [ -z "$vdesc" ] && vdesc="(não encontrado)"

            case "${apago,,}" in
                true)  pg="Sim" ;;
                false) pg="Não" ;;
                *)     pg="?"   ;;
            esac

            printf '%-10.10s %-24.24s %-22.22s %-10.10s %9s %-4s %-11.11s %-11.11s\n' \
                "$aid" "$ncli" "$vdesc" "$aplaca" \
                "${avalor/null/-}" "$pg" "${aret/null/-}" "${adev/null/-}"
        done <<< "$bruto"

        total=$(printf '%s\n' "$bruto" | grep -c .)
        pend=$(printf '%s\n' "$bruto" | awk -F"$SEP" 'tolower($8) != "true"' | grep -c .)
        soma=$(printf '%s\n' "$bruto" | awk -F"$SEP" '($7 != "null" && $7 != "") { s += $7 } END { printf "%.2f", s }')

        printf '\n%s\n' "--------------------------------------------------------------------------------"
        printf 'Aluguéis: %s   |   Pagos: %s   |   Pendentes: %s   |   Soma dos valores: %s\n' \
            "$total" "$((total - pend))" "$pend" "$soma"
    } > "$TMP/alugueis.txt"

    dialog --title "Histórico de Aluguéis" --textbox "$TMP/alugueis.txt" 24 "$LARGURA"
}

menu_alugueis() {
    local opcao dados id_aluguel id_cli placa_veic valor pago dt_ret dt_dev
    local nome_cli modelo_veic marca_veic veic atual atual_pago padrao msg_ok
    local ac_idcli ac_nome ac_placa ac_modelo ac_valor ac_pago ac_ret ac_dev

    while true; do
        opcao=$(dialog --stdout --menu "Registro de Aluguéis" 15 55 5 \
            1 "Registrar Novo Aluguel" \
            2 "Listar Todos os Aluguéis" \
            3 "Atualizar Status de Pagamento" \
            4 "Excluir Aluguel" \
            0 "Voltar") || return

        case "$opcao" in
            1)
                dados=$(dialog --stdout --form "Novo Aluguel" 16 62 0 \
                    "ID Aluguel:"                    1 1 ""      1 26 15 0 \
                    "ID/CPF Cliente:"                2 1 ""      2 26 20 0 \
                    "Placa Veículo:"                 3 1 ""      3 26 15 0 \
                    "Valor (ex: 150.00):"            4 1 ""      4 26 15 0 \
                    "Pago (true/false):"             5 1 "false" 5 26 10 0 \
                    "Data Retirada (AAAA-MM-DD):"    6 1 ""      6 26 15 0 \
                    "Data Devolução (AAAA-MM-DD):"   7 1 ""      7 26 15 0) || continue

                id_aluguel=$(trim "$(printf '%s\n' "$dados" | sed -n '1p')")
                id_cli=$(trim     "$(printf '%s\n' "$dados" | sed -n '2p')")
                placa_veic=$(trim "$(printf '%s\n' "$dados" | sed -n '3p')")
                valor=$(trim     "$(printf '%s\n' "$dados" | sed -n '4p')")
                pago=$(trim      "$(printf '%s\n' "$dados" | sed -n '5p')")
                dt_ret=$(trim    "$(printf '%s\n' "$dados" | sed -n '6p')")
                dt_dev=$(trim    "$(printf '%s\n' "$dados" | sed -n '7p')")

                # --- validação, campo por campo ---
                if vazio "$id_aluguel"; then erro "O ID do aluguel é obrigatório."; continue; fi
                if vazio "$id_cli";     then erro "O cliente é obrigatório.";        continue; fi
                if vazio "$placa_veic"; then erro "A placa do veículo é obrigatória."; continue; fi
                if ! validar_valor "$valor"; then
                    erro "Valor inválido: '$valor'.

Use apenas números, com até 2 casas decimais (ex.: 150.00)."
                    continue
                fi
                pago=$(printf '%s' "$pago" | tr '[:upper:]' '[:lower:]')
                if [ "$pago" != "true" ] && [ "$pago" != "false" ]; then
                    erro "O campo Pago deve ser true ou false (digitado: '$pago')."
                    continue
                fi
                if ! validar_data "$dt_ret"; then
                    erro "Data de retirada inválida: '$dt_ret'.

Use o formato AAAA-MM-DD (ex.: 2026-03-15)."
                    continue
                fi
                if ! validar_data "$dt_dev"; then
                    erro "Data de devolução inválida: '$dt_dev'.

Use o formato AAAA-MM-DD (ex.: 2026-03-20)."
                    continue
                fi
                if [[ "$dt_dev" < "$dt_ret" ]]; then
                    erro "A devolução ($dt_dev) não pode ser anterior à retirada ($dt_ret)."
                    continue
                fi

                # --- confere se cliente e veículo existem e traz os nomes ---
                nome_cli=$(tsv "SELECT nome FROM clientes WHERE id='$(esc "$id_cli")';")
                if [ -z "$nome_cli" ]; then
                    erro "Cliente '$id_cli' não encontrado.

Cadastre o cliente antes de registrar o aluguel (menu Clientes)."
                    continue
                fi
                [ "$nome_cli" = "null" ] && nome_cli=""

                veic=$(tsv "SELECT modelo, marca FROM automoveis WHERE placa='$(esc "$placa_veic")';")
                if [ -z "$veic" ]; then
                    erro "Veículo '$placa_veic' não encontrado.

Cadastre o veículo antes de registrar o aluguel (menu Automóveis)."
                    continue
                fi
                IFS="$SEP" read -r modelo_veic marca_veic <<< "$veic"
                [ "$modelo_veic" = "null" ] && modelo_veic=""
                [ "$marca_veic"  = "null" ] && marca_veic=""

                msg_ok="Aluguel registrado com sucesso!

ID:       $id_aluguel
Cliente:  $nome_cli ($id_cli)
Veículo:  $(printf '%s' "$modelo_veic${marca_veic:+ / $marca_veic}") - $placa_veic
Valor:    $valor
Pago:     $pago
Retirada: $dt_ret     Devolução: $dt_dev"

                gravar "INSERT INTO alugueis (id, id_cliente, nome_cliente, placa_veiculo, modelo_veiculo, marca_veiculo, valor, pago, data_retirada, data_devolucao) VALUES ('$(esc "$id_aluguel")', '$(esc "$id_cli")', '$(esc "$nome_cli")', '$(esc "$placa_veic")', '$(esc "$modelo_veic")', '$(esc "$marca_veic")', $valor, $pago, '$(esc "$dt_ret")', '$(esc "$dt_dev")') IF NOT EXISTS;" \
                    "$msg_ok" \
                    "Já existe um aluguel com o ID '$id_aluguel'.

Use outro ID ou exclua o aluguel existente."
                ;;

            2)
                listar_alugueis
                ;;

            3)
                id_aluguel=$(dialog --stdout --inputbox "Digite o ID do aluguel para alterar o pagamento:" 8 50) || continue
                id_aluguel=$(trim "$id_aluguel")
                if vazio "$id_aluguel"; then erro "Informe o ID do aluguel."; continue; fi

                atual=$(tsv "SELECT nome_cliente, placa_veiculo, valor, pago FROM alugueis WHERE id='$(esc "$id_aluguel")';")
                if [ -z "$atual" ]; then
                    erro "Aluguel '$id_aluguel' não encontrado."
                    continue
                fi
                IFS="$SEP" read -r ac_nome ac_placa ac_valor atual_pago <<< "$atual"

                padrao="false"
                [ "$atual_pago" = "True" ] && padrao="true"

                pago=$(dialog --stdout --default-item "$padrao" --menu "O aluguel '$id_aluguel' está pago?

Cliente: ${ac_nome/null/-}   Veículo: ${ac_placa/null/-}   Valor: ${ac_valor/null/-}" \
                    14 62 2 \
                    "true"  "Sim, está pago" \
                    "false" "Não, pendente") || continue

                gravar "UPDATE alugueis SET pago=$pago WHERE id='$(esc "$id_aluguel")' IF EXISTS;" \
                    "Status de pagamento atualizado para '$pago'." \
                    "O aluguel '$id_aluguel' não existe mais."
                ;;

            4)
                id_aluguel=$(dialog --stdout --inputbox "Digite o ID do aluguel para EXCLUIR:" 8 50) || continue
                id_aluguel=$(trim "$id_aluguel")
                if vazio "$id_aluguel"; then erro "Informe o ID do aluguel."; continue; fi

                atual=$(tsv "SELECT id_cliente, nome_cliente, placa_veiculo, modelo_veiculo, valor, pago, data_retirada, data_devolucao FROM alugueis WHERE id='$(esc "$id_aluguel")';")
                if [ -z "$atual" ]; then
                    erro "Aluguel '$id_aluguel' não encontrado."
                    continue
                fi
                IFS="$SEP" read -r ac_idcli ac_nome ac_placa ac_modelo ac_valor ac_pago ac_ret ac_dev <<< "$atual"

                # registros antigos podem não ter nome_cliente gravado
                [ "$ac_nome" = "null" ] || [ -z "$ac_nome" ] && ac_nome="(cliente $ac_idcli)"
                case "${ac_pago,,}" in
                    true)  ac_pago="Sim" ;;
                    false) ac_pago="Não" ;;
                    *)     ac_pago="?"   ;;
                esac

                dialog --title "Confirmar exclusão" --yesno "Excluir definitivamente o aluguel '$id_aluguel'?

Cliente:  $ac_nome
Veículo:  ${ac_modelo/null/-} (${ac_placa/null/-})
Valor:    ${ac_valor/null/-}   Pago: $ac_pago
Retirada: ${ac_ret/null/-}   Devolução: ${ac_dev/null/-}

Esta ação não pode ser desfeita." 0 0 || continue

                gravar "DELETE FROM alugueis WHERE id='$(esc "$id_aluguel")' IF EXISTS;" \
                    "Aluguel excluído!" \
                    "O aluguel '$id_aluguel' não existe mais."
                ;;

            *) return ;;
        esac
    done
}


# =============================================================================
#  8. Menu principal
# =============================================================================

main() {
    local opcao_principal

    requisitos
    resolver_container
    aguardar_cqlsh
    init_database

    while true; do
        opcao_principal=$(dialog --stdout --menu "Sistema de Locadora de Veículos" 15 50 4 \
            1 "Clientes" \
            2 "Automóveis" \
            3 "Aluguéis" \
            0 "Sair") || break

        case "$opcao_principal" in
            1) menu_clientes ;;
            2) menu_automoveis ;;
            3) menu_alugueis ;;
            *) break ;;
        esac
    done

    clear
    echo "Encerrando o sistema."
}

main "$@"
