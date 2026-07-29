================================================================================
 PASTA: 06_Projeto_Integrador - Banco de Dados II
 Projeto final: Catálogo de Filmes com múltiplos bancos
================================================================================

 PRÉ-REQUISITOS:
 - MongoDB, Redis e Cassandra instalados e rodando
   (execute 00_Setup/instalar_tudo.sh ou Docker Compose)
 - mongosh, redis-cli e cqlsh disponíveis

 VISÃO GERAL:
   Sistema de catálogo de filmes que utiliza três bancos NoSQL
   diferentes, cada um para sua finalidade específica:

   +----------+              +----------+
   | MongoDB  |  (dados     |  Redis   |  (cache de
   | filmes   |<--principais)| consultas)|<--consultas
   +----------+              +----------+
        ^                          ^
        |                          |
   +----+--------------------------+----+
   |         Aplicação CLI              |
   +------------------------------------+
        ^
        |
   +----------+
   | Cassandra|  (logs de acesso)
   +----------+

 ARQUIVOS:
   01_ingestao_mongodb.sh
      Popula o MongoDB com 20 filmes (título, ano, gênero,
      diretor, nota, sinopse).

   02_cache_redis.sh
      Consulta filme no MongoDB e armazena resultado no Redis
      com TTL de 60 segundos. Na segunda consulta, busca do
      cache (mais rápido).

   03_logs_cassandra.cql
      Cria tabela de logs de acesso no Cassandra.
      Cada consulta a um filme gera um registro de log.

 COMO EXECUTAR (ORDEM):
   1. mongosh < 01_ingestao_mongodb.sh
   2. cat 03_logs_cassandra.cql | cqlsh
   3. ./02_cache_redis.sh

 CONSULTAS PARA TESTAR:
   # MongoDB - listar filmes por gênero
   use cinema
   db.filmes.find({genero: "Ficção Científica"}).pretty()

   # MongoDB - top 5 melhores notas
   db.filmes.find().sort({nota: -1}).limit(5).pretty()

   # Redis - verificar cache
   redis-cli keys "filme:*"
   redis-cli get "filme:Matrix"

   # Cassandra - consultar logs
   SELECT * FROM cinema.logs WHERE filme = 'Matrix';
================================================================================
