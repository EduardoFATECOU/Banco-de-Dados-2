#!/usr/bin/env bash
# =============================================================================
# Simulação de cache com Redis
#
# Demonstra como o Redis pode ser usado como camada de cache para reduzir
# o tempo de resposta de consultas a um banco de dados (simulado).
#
# Uso: chmod +x 02_cache_simulacao.sh && ./02_cache_simulacao.sh
# Requer: redis-cli instalado e Redis rodando
# =============================================================================

set -e

echo "================================================================"
echo "  REDIS — Simulação de Cache"
echo "================================================================"
echo ""

# Limpa o Redis
redis-cli FLUSHDB > /dev/null

# ------------------------------------------------------------------
# Função que simula uma consulta lenta ao banco de dados
# Recebe um ID e retorna dados "do banco" após 2 segundos
# ------------------------------------------------------------------
buscar_do_banco() {
    local id=$1
    echo "    [BANCO] Consulta lenta ao banco de dados (ID: $id)..."
    sleep 2  # Simula latência de banco
    echo "    [BANCO] Dados retornados: { id: $id, nome: 'Produto $id', preco: $((RANDOM % 500 + 50)).00 }"
    echo "{\"id\":$id,\"nome\":\"Produto $id\",\"preco\":$((RANDOM % 500 + 50)).00}"
}

# ------------------------------------------------------------------
# Função que busca dados usando cache (Redis primeiro, banco depois)
# ------------------------------------------------------------------
buscar_com_cache() {
    local id=$1
    local cache_key="produto:$id"

    echo ""
    echo ">>> Buscando produto $id..."

    # 1. Verifica se está no cache (Redis)
    local cached
    cached=$(redis-cli GET "$cache_key")

    if [ -n "$cached" ]; then
        echo "    [CACHE] Dados encontrados no Redis!"
        echo "    [CACHE] Valor: $cached"
        return
    fi

    echo "    [CACHE] Dados NÃO encontrados no cache."

    # 2. Se não está no cache, busca no "banco de dados"
    local dados
    dados=$(buscar_do_banco "$id")

    echo "    [CACHE] Armazenando no Redis com EXPIRE de 30 segundos..."

    # 3. Armazena no Redis com tempo de expiração (30s)
    redis-cli SET "$cache_key" "$dados" EX 30 > /dev/null

    echo "    [CACHE] Dados armazenados em cache: $dados"
}

# ------------------------------------------------------------------
# Demonstração
# ------------------------------------------------------------------
echo "Vamos simular 4 consultas ao produto 42:"
echo "  1ª consulta: sem cache (vai ao 'banco')"
echo "  2ª consulta: com cache (retorna imediato)"
echo "  3ª consulta: com cache (retorna imediato)"
echo "  4ª consulta: após expirar cache (volta ao banco)"
echo ""

sleep 1

echo "================================================================"
echo "  1ª CONSULTA — Sem cache (deve ir ao banco)"
echo "================================================================"
time buscar_com_cache 42

echo ""
sleep 1

echo "================================================================"
echo "  2ª CONSULTA — Com cache (deve ser rápida)"
echo "================================================================"
time buscar_com_cache 42

echo ""
sleep 1

echo "================================================================"
echo "  3ª CONSULTA — Com cache (ainda rápido)"
echo "================================================================"
time buscar_com_cache 42

echo ""
sleep 1

echo "================================================================"
echo "  Removendo cache manualmente..."
echo "================================================================"
redis-cli DEL "produto:42" > /dev/null
echo "  Cache removido via DEL."
echo ""

sleep 1

echo "================================================================"
echo "  4ª CONSULTA — Cache removido (deve ir ao banco novamente)"
echo "================================================================"
time buscar_com_cache 42

echo ""
echo "================================================================"
echo "  RESUMO DA SIMULAÇÃO"
echo "================================================================"
echo ""
echo "  Consulta 1 (sem cache):  ~2 segundos (banco de dados)"
echo "  Consulta 2 (com cache):  ~0 segundos (Redis)"
echo "  Consulta 3 (com cache):  ~0 segundos (Redis)"
echo "  Consulta 4 (cache expirado): ~2 segundos (banco de dados)"
echo ""
echo "O Redis pode reduzir drasticamente a latência de consultas"
echo "repetitivas, funcionando como uma camada rápida antes do"
echo "banco de dados principal."
echo ""

# Limpa o Redis
redis-cli FLUSHDB > /dev/null
echo "Cache limpo ao final."
