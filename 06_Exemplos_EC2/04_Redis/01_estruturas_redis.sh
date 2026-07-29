#!/usr/bin/env bash
# =============================================================================
# Demonstração das principais estruturas de dados do Redis
#
# Redis é um banco de dados em memória que suporta多种 estruturas:
# Strings, Lists, Sets, Hashes, Sorted Sets e mais.
#
# Uso: chmod +x 01_estruturas_redis.sh && ./01_estruturas_redis.sh
# Requer: redis-cli instalado e Redis rodando
# =============================================================================

set -e

echo "================================================================"
echo "  REDIS — Estruturas de Dados"
echo "================================================================"
echo ""

# Limpa qualquer chave de execuções anteriores
redis-cli FLUSHDB > /dev/null

# ==========================================================================
# 1. STRINGS — A estrutura mais simples (chave -> valor)
# ==========================================================================
echo "================================================================"
echo "  1. STRINGS"
echo "================================================================"
echo ""

# SET: define o valor de uma chave
redis-cli SET usuario:1 "Ana Silva"
echo "  SET usuario:1 'Ana Silva'"

# GET: obtém o valor
echo "  GET usuario:1 => $(redis-cli GET usuario:1)"

# INCR: incrementa valor numérico (atômico)
redis-cli INCR contador
redis-cli INCR contador
redis-cli INCR contador
echo "  INCR contador (3x) => $(redis-cli GET contador)"

# EXPIRE: define tempo de expiração (em segundos)
redis-cli SET token "abc123" EX 10
echo "  SET token 'abc123' EX 10 (expira em 10s)"

# TTL: mostra tempo restante de vida
echo "  TTL token => $(redis-cli TTL token)s restantes"
echo ""

sleep 1

# ==========================================================================
# 2. LISTS — Listas ordenadas (como filas ou pilhas)
# ==========================================================================
echo "================================================================"
echo "  2. LISTS (Listas)"
echo "================================================================"
echo ""

# LPUSH: adiciona ao início (esquerda)
redis-cli LPUSH tarefas "Comprar pão"
redis-cli LPUSH tarefas "Estudar Redis"
redis-cli LPUSH tarefas "Reunião às 14h"
echo "  LPUSH tarefas 'Comprar pão' 'Estudar Redis' 'Reunião às 14h'"

# RPUSH: adiciona ao final (direita)
redis-cli RPUSH tarefas "Ler emails"
echo "  RPUSH tarefas 'Ler emails'"

# LRANGE: lista elementos (índices 0 a -1 = todos)
echo "  LRANGE tarefas 0 -1 => $(redis-cli LRANGE tarefas 0 -1 | tr '\n' ' ')"

# LPOP: remove do início
echo "  LPOP tarefas => $(redis-cli LPOP tarefas)"

# RPOP: remove do final
echo "  RPOP tarefas => $(redis-cli RPOP tarefas)"

echo "  LRANGE tarefas 0 -1 (após pops) => $(redis-cli LRANGE tarefas 0 -1 | tr '\n' ' ')"
echo ""

sleep 1

# ==========================================================================
# 3. SETS — Conjuntos não ordenados (sem duplicatas)
# ==========================================================================
echo "================================================================"
echo "  3. SETS (Conjuntos)"
echo "================================================================"
echo ""

# SADD: adiciona membros ao conjunto
redis-cli SADD linguagens "Python"
redis-cli SADD linguagens "JavaScript"
redis-cli SADD linguagens "Java"
redis-cli SADD linguagens "Python"  # Ignorado (já existe)
echo "  SADD linguagens Python JavaScript Java Python (2º ignorado)"

# SMEMBERS: lista todos os membros
echo "  SMEMBERS linguagens => $(redis-cli SMEMBERS linguagens | tr '\n' ' ')"

# Cria segundo conjunto para operações de conjunto
redis-cli SADD frontend "JavaScript"
redis-cli SADD frontend "HTML"
redis-cli SADD frontend "CSS"

# SINTER: interseção entre conjuntos
echo "  SINTER linguagens frontend => $(redis-cli SINTER linguagens frontend | tr '\n' ' ')"

# SUNION: união entre conjuntos
echo "  SUNION linguagens frontend => $(redis-cli SUNION linguagens frontend | tr '\n' ' ')"
echo ""

sleep 1

# ==========================================================================
# 4. HASHES — Mapas de campos-valor (como objetos)
# ==========================================================================
echo "================================================================"
echo "  4. HASHES (Mapas)"
echo "================================================================"
echo ""

# HSET: define campos em um hash
redis-cli HSET pessoa:1 nome "Carlos Lima" idade 30 cidade "São Paulo"
echo "  HSET pessoa:1 nome 'Carlos Lima' idade 30 cidade 'São Paulo'"

# HGET: obtém um campo específico
echo "  HGET pessoa:1 nome => $(redis-cli HGET pessoa:1 nome)"

# HGETALL: obtém todos os campos e valores
echo "  HGETALL pessoa:1 =>"
redis-cli HGETALL pessoa:1 | paste - - | while read -r field value; do
    echo "    $field: $value"
done

# HINCRBY: incrementa campo numérico
redis-cli HINCRBY pessoa:1 idade 1
echo "  HINCRBY pessoa:1 idade 1 => idade agora é $(redis-cli HGET pessoa:1 idade)"
echo ""

sleep 1

# ==========================================================================
# 5. SORTED SETS — Conjuntos ordenados (com score)
# ==========================================================================
echo "================================================================"
echo "  5. SORTED SETS (Conjuntos Ordenados)"
echo "================================================================"
echo ""

# ZADD: adiciona membros com score (nota/peso)
redis-cli ZADD ranking 85 "Ana"
redis-cli ZADD ranking 92 "Carlos"
redis-cli ZADD ranking 78 "Marina"
redis-cli ZADD ranking 95 "Rafael"
echo "  ZADD ranking 85 Ana 92 Carlos 78 Marina 95 Rafael"

# ZRANGE: lista membros em ordem crescente de score
echo "  ZRANGE ranking 0 -1 (crescente) => $(redis-cli ZRANGE ranking 0 -1 | tr '\n' ' ')"

# ZREVRANGE: lista membros em ordem decrescente de score
echo "  ZREVRANGE ranking 0 -1 (decrescente) => $(redis-cli ZREVRANGE ranking 0 -1 | tr '\n' ' ')"

# ZRANK: posição de um membro (0-indexed, ordem crescente)
echo "  ZRANK ranking 'Ana' => posição $(redis-cli ZRANK ranking 'Ana')"
echo ""

sleep 1

# ==========================================================================
# 6. LIMPEZA
# ==========================================================================
redis-cli FLUSHDB > /dev/null

echo "================================================================"
echo "  RESUMO DAS ESTRUTURAS"
echo "================================================================"
echo ""
echo "  +----------------+-------------------------------------------+"
echo "  | Estrutura      | Uso típico                                |"
echo "  +----------------+-------------------------------------------+"
echo "  | Strings        | Cache simples, contadores, sessões        |"
echo "  | Lists          | Filas (LPUSH + BRPOP), timeline           |"
echo "  | Sets           | Tags, relacionamentos, unicidade          |"
echo "  | Hashes         | Objetos, perfis de usuário                |"
echo "  | Sorted Sets    | Rankings, leaderboards, filas prioritárias|"
echo "  +----------------+-------------------------------------------+"
echo ""
echo "Redis armazena tudo em memória RAM — operações em microssegundos."
echo "Demonstração concluída."
