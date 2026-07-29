#!/usr/bin/env bash
# =============================================================================
# Projeto Integrador — Cache de consultas com Redis
#
# Demonstra o uso do Redis como camada de cache entre o cliente e o MongoDB.
# Consultas frequentes sao armazenadas em cache para reduzir latencia.
#
# Uso: chmod +x 02_cache_redis.sh && ./02_cache_redis.sh
# Requer: mongosh, redis-cli instalados e servicos rodando
# =============================================================================

set -e

echo "================================================================"
echo "  PROJETO INTEGRADOR — Cache de Filmes com Redis"
echo "================================================================"
echo ""

# Limpa cache anterior
redis-cli FLUSHDB > /dev/null

# ------------------------------------------------------------------
# Funcao: busca filme pelo titulo (primeiro verifica cache, depois MongoDB)
# ------------------------------------------------------------------
buscar_filme() {
    local titulo=$1
    local cache_key="filme:$(echo "$titulo" | tr ' ' '_' | tr -d ':')"

    echo ""
    echo ">>> Buscando filme: '$titulo'"

    # 1. Verificar cache no Redis
    local cached
    cached=$(redis-cli GET "$cache_key")

    if [ -n "$cached" ]; then
        echo "    [CACHE] ENCONTRADO no Redis!"
        echo "    [CACHE] Dados: $cached"
        return
    fi

    echo "    [CACHE] Nao encontrado. Consultando MongoDB..."

    # 2. Buscar no MongoDB via mongosh
    local mongo_result
    mongo_result=$(mongosh --quiet --eval "
        use('filmes');
        const f = db.catalogo.findOne({ titulo: '$titulo' });
        if (f) print(f.titulo + ' | ' + f.ano + ' | ' + f.genero + ' | Nota: ' + f.nota);
        else print('NAO_ENCONTRADO');
    " 2>/dev/null)

    if [ "$mongo_result" = "NAO_ENCONTRADO" ]; then
        echo "    [ERRO] Filme nao encontrado no MongoDB!"
        return
    fi

    echo "    [MONGODB] Resultado: $mongo_result"

    # 3. Armazenar em cache com EXPIRE de 30 segundos
    redis-cli SET "$cache_key" "$mongo_result" EX 30 > /dev/null
    echo "    [CACHE] Armazenado em Redis (expira em 30s): $cache_key"
}

# ------------------------------------------------------------------
# Demonstracao
# ------------------------------------------------------------------
echo "Vamos buscar alguns filmes do catalogo MongoDB usando cache Redis."
echo ""
echo "Primeira busca vai ao MongoDB; as seguintes vao ao cache."
echo ""

sleep 1

echo "================================================================"
echo "  BUSCA 1: Matrix (sem cache — vai ao MongoDB)"
echo "================================================================"
time buscar_filme "Matrix"

sleep 1

echo ""
echo "================================================================"
echo "  BUSCA 2: Matrix (com cache — retorna do Redis)"
echo "================================================================"
time buscar_filme "Matrix"

sleep 1

echo ""
echo "================================================================"
echo "  BUSCA 3: Matrix (ainda em cache)"
echo "================================================================"
time buscar_filme "Matrix"

sleep 1

echo ""
echo "================================================================"
echo "  BUSCA 4: Interestelar (sem cache — vai ao MongoDB)"
echo "================================================================"
time buscar_filme "Interestelar"

sleep 1

echo ""
echo "================================================================"
echo "  BUSCA 5: Interestelar (com cache)"
echo "================================================================"
time buscar_filme "Interestelar"

sleep 1

echo ""
echo "================================================================"
echo "  VERIFICANDO CHAVES NO REDIS"
echo "================================================================"
echo ""
echo "Chaves em cache:"
redis-cli KEYS "filme:*"
echo ""

echo "Tempo restante de vida do cache 'filme:Matrix':"
redis-cli TTL "filme:Matrix"
echo "segundos"
echo ""

echo "================================================================"
echo "  CONCLUSAO"
echo "================================================================"
echo ""
echo "O Redis atua como cache para evitar consultas repetitivas ao"
echo "MongoDB. A primeira busca demora (consulta ao banco), mas as"
echo "demais sao instantaneas (retorno do cache em memoria)."
echo ""
echo "Beneficios:"
echo "  - Reducao de latencia (microssegundos vs milissegundos)"
echo "  - Menos carga no MongoDB"
echo "  - Escalabilidade para picos de acesso"
echo ""

# Limpa cache
redis-cli FLUSHDB > /dev/null
echo "Cache limpo ao final."
