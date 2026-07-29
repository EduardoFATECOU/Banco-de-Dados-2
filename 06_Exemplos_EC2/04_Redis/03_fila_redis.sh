#!/usr/bin/env bash
# =============================================================================
# Simulação de fila de tarefas com Redis Lists
#
# Redis Lists com LPUSH (produtor) e BRPOP (consumidor) formam uma
# fila robusta para processamento assíncrono de tarefas.
#
# Uso: chmod +x 03_fila_redis.sh && ./03_fila_redis.sh
# Requer: redis-cli instalado e Redis rodando
# =============================================================================

set -e

echo "================================================================"
echo "  REDIS — Fila de Tarefas (Task Queue)"
echo "================================================================"
echo ""

# Limpa o Redis
redis-cli FLUSHDB > /dev/null

FILA="fila:tarefas"

# ------------------------------------------------------------------
# Função produtora: adiciona tarefas à fila
# ------------------------------------------------------------------
produzir_tarefas() {
    local qtde=$1
    echo ">>> Produtor: adicionando $qtde tarefas à fila..."

    for i in $(seq 1 $qtde); do
        local tarefa="tarefa_$i"
        # LPUSH adiciona ao início da lista
        redis-cli LPUSH "$FILA" "$tarefa" > /dev/null
        echo "    [PRODUTOR] Adicionada: $tarefa"
        sleep 0.3
    done

    local total
    total=$(redis-cli LLEN "$FILA")
    echo "    [PRODUTOR] Total de tarefas na fila: $total"
    echo ""
}

# ------------------------------------------------------------------
# Função consumidora: processa tarefas da fila
# ------------------------------------------------------------------
consumir_tarefas() {
    local worker_id=$1
    local qtde=$2
    local processadas=0

    echo ">>> Worker $worker_id: iniciando processamento de $qtde tarefas..."

    for i in $(seq 1 $qtde); do
        # BRPOP: bloqueia até aparecer um item (timeout de 5s)
        # Retorna: nome_da_lista valor
        local resultado
        resultado=$(redis-cli BRPOP "$FILA" 2 2>/dev/null)

        if [ -n "$resultado" ]; then
            # Extrai o valor (segunda linha)
            local tarefa
            tarefa=$(echo "$resultado" | tail -1)
            processadas=$((processadas + 1))
            echo "    [WORKER $worker_id] Processando: $tarefa"
            sleep 1  # Simula tempo de processamento
            echo "    [WORKER $worker_id] Finalizada: $tarefa"
        else
            echo "    [WORKER $worker_id] Tempo limite (fila vazia)"
            break
        fi
    done

    echo "    [WORKER $worker_id] Processadas $processadas tarefas"
    echo ""
}

# ------------------------------------------------------------------
# Demonstração
# ------------------------------------------------------------------
echo "Simulação de uma fila de tarefas com Redis:"
echo ""
echo "  - Produtor adiciona tarefas com LPUSH"
echo "  - Workers consomem tarefas com BRPOP (bloqueante)"
echo "  - LLEN mostra o tamanho da fila"
echo ""

sleep 2

# 1. Produtor adiciona 6 tarefas
echo "================================================================"
echo "  FASE 1: Produzindo tarefas"
echo "================================================================"
produzir_tarefas 6

sleep 1

# 2. Mostra tamanho da fila
echo "================================================================"
echo "  STATUS DA FILA"
echo "================================================================"
total_fila=$(redis-cli LLEN "$FILA")
echo "  LLEN $FILA => $total_fila tarefas aguardando"
echo ""

sleep 1

# 3. Workers consomem em paralelo (simulação sequencial para demonstração)
echo "================================================================"
echo "  FASE 2: Processando com Workers"
echo "================================================================"
echo ""

echo "Worker 1 vai processar 3 tarefas..."
consumir_tarefas 1 3

echo "Worker 2 vai processar as 3 tarefas restantes..."
consumir_tarefas 2 3

sleep 1

# 4. Verifica fila vazia
echo "================================================================"
echo "  STATUS FINAL DA FILA"
echo "================================================================"
total_final=$(redis-cli LLEN "$FILA")
echo "  LLEN $FILA => $total_final tarefas restantes"
echo ""

sleep 1

# 5. Demonstra produtor + consumidor em tempo real
echo "================================================================"
echo "  FASE 3: Produção e consumo simultâneos"
echo "================================================================"
echo ""

# Adiciona tarefas enquanto worker processa
redis-cli LPUSH "$FILA" "tarefa_urgente" > /dev/null
echo "  [PRODUTOR] Tarefa urgente adicionada!"

# Worker processa imediatamente
echo "  [WORKER] Aguardando tarefa com BRPOP..."
resultado=$(redis-cli BRPOP "$FILA" 3 2>/dev/null)
if [ -n "$resultado" ]; then
    tarefa=$(echo "$resultado" | tail -1)
    echo "  [WORKER] Recebeu e processou: $tarefa"
fi

echo ""
echo "================================================================"
echo "  CONCLUSÃO"
echo "================================================================"
echo ""
echo "Redis Lists com LPUSH + BRPOP formam uma fila:"
echo ""
echo "  - Produtores chamam LPUSH para adicionar tarefas"
echo "  - Consumidores chamam BRPOP para retirar (bloqueante)"
echo "  - LLEN monitora o tamanho da fila"
echo "  - Múltiplos workers podem consumir em paralelo"
echo ""
echo "Isso é a base de sistemas como Celery, Bull (Node.js) e"
echo "Sidekiq (Ruby) para processamento assíncrono."
echo ""

# Limpa o Redis
redis-cli FLUSHDB > /dev/null
echo "Fila limpa ao final."
