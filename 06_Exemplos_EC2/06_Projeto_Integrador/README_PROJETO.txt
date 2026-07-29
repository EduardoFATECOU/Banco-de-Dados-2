================================================================================
  PROJETO INTEGRADOR — SISTEMA DE CATÁLOGO DE FILMES
  MongoDB + Redis + Cassandra
================================================================================

Este projeto integrador demonstra o uso de três bancos de dados NoSQL
trabalhando juntos em um sistema completo:

  - MongoDB:   Armazenamento principal dos dados dos filmes (documentos)
  - Redis:     Cache de consultas frequentes (performance)
  - Cassandra: Logs de acesso e séries temporais (auditoria)

--------------------------------------------------------------------------------
ARQUITETURA
--------------------------------------------------------------------------------

                         +-----------+
                         |  Cliente  |
                         +-----+-----+
                               |
                    +----------+----------+
                    |                     |
            +-------v-------+     +------v-------+
            |   MongoDB     |     |    Redis     |
            |  (dados dos   |     |   (cache)    |
            |   filmes)     |     |              |
            +---------------+     +--------------+
                    |
            +-------v-------+
            |   Cassandra   |
            |  (logs de     |
            |   acesso)     |
            +---------------+

Fluxo de uma consulta:
  1. Cliente busca filme por título
  2. Sistema verifica Redis (cache)
     - Se encontrar: retorna imediatamente (rápido)
     - Se não encontrar: consulta MongoDB, armazena em Redis com EXPIRE
  3. Cada consulta gera um log no Cassandra (timestamp, IP, filme)
  4. Logs podem ser analisados para relatórios de acesso

--------------------------------------------------------------------------------
ESTRUTURA DOS ARQUIVOS
--------------------------------------------------------------------------------

  01_ingestao_mongodb.sh
      Popula o MongoDB com 20 filmes (título, ano, gênero, diretor, nota).
      Cria o database "filmes" e a coleção "catalogo".

  02_cache_redis.sh
      Demonstra o uso do Redis como cache:
        - Verifica se filme está em cache (GET)
        - Se não, busca no MongoDB e armazena com EXPIRE
        - Mostra diferença de tempo com/sem cache

  03_logs_cassandra.cql
      Cria keyspace e tabela de logs de acesso no Cassandra.
      Insere dados de exemplo e faz consultas.
      Estrutura: id_filme, titulo, timestamp, ip, acao.

--------------------------------------------------------------------------------
COMO EXECUTAR (na EC2)
--------------------------------------------------------------------------------

  1. Certifique-se de que MongoDB, Redis e Cassandra estão rodando:
       sudo systemctl status mongod
       sudo systemctl status redis-server
       sudo systemctl status cassandra

  2. Popule o MongoDB com os filmes:
       ./01_ingestao_mongodb.sh

  3. Teste o cache Redis:
       ./02_cache_redis.sh

  4. Configure os logs no Cassandra:
       cat 03_logs_cassandra.cql | cqlsh

  5. (Opcional) Execute tudo em sequência:
       ./01_ingestao_mongodb.sh
       ./02_cache_redis.sh
       cat 03_logs_cassandra.cql | cqlsh

--------------------------------------------------------------------------------
CONSULTAS DE EXEMPLO
--------------------------------------------------------------------------------

  MongoDB — Listar filmes de um gênero:
      mongosh --eval 'use("filmes");
          db.catalogo.find({ genero: "Ficção Científica" },
              { titulo: 1, ano: 1, diretor: 1, _id: 0 });'

  Redis — Verificar cache:
      redis-cli GET "filme:Matrix"

  Cassandra — Consultar logs de acesso:
      cqlsh -e "USE cinema; SELECT * FROM logs_acesso WHERE id_filme = 7;"

--------------------------------------------------------------------------------
EXPANSÕES POSSÍVEIS
--------------------------------------------------------------------------------

  - Adicionar Elasticsearch para busca textual nos filmes
  - Adicionar Neo4j para recomendações (grafo de "usuários que viram X
    também viram Y")
  - Criar API REST (Python/Flask ou Node.js) para integrar os serviços
  - Dashboard com Kibana para visualizar logs de acesso

================================================================================
