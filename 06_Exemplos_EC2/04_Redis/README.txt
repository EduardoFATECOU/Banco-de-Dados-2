================================================================================
 PASTA: 04_Redis - Banco de Dados II
 Exemplos de estruturas de dados, cache e fila no Redis
================================================================================

 PRÉ-REQUISITOS:
 - Redis Server instalado e rodando
   >> Use: sudo systemctl start redis-server
 - redis-cli instalado

 ARQUIVOS:
   01_estruturas_redis.sh
      Demonstra todas as principais estruturas do Redis:
      Strings, Lists, Sets, Hashes, Sorted Sets.
      Comandos: SET, GET, LPUSH, RPUSH, LRANGE, SADD,
      SMEMBERS, HSET, HGETALL, ZADD, ZRANGE.

   02_cache_simulacao.sh
      Simula cache com Redis: "busca dados do banco"
      (simulado com sleep 2s) e armazena em cache com EXPIRE.
      Mede tempo com e sem cache usando time.

   03_fila_redis.sh
      Implementa fila de tarefas com Redis Lists:
      produtor adiciona tarefas (LPUSH), consumidor
      processa (BRPOP). Simula workers concorrentes.

 COMO EXECUTAR:
   chmod +x *.sh
   ./01_estruturas_redis.sh
   ./02_cache_simulacao.sh
   ./03_fila_redis.sh

 ORDEM RECOMENDADA:
   1. 01_estruturas_redis.sh  (conhecer os tipos de dados)
   2. 02_cache_simulacao.sh   (aplicação prática: cache)
   3. 03_fila_redis.sh        (aplicação prática: fila)

 DICA: Redis Insights é uma GUI gratuita para visualizar
   os dados. Baixe em: https://redis.com/redis-enterprise/redis-insight/
================================================================================
