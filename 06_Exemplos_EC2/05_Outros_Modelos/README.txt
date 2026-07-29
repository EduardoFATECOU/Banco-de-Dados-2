================================================================================
 PASTA: 05_Outros_Modelos - Banco de Dados II
 Exemplos de Neo4j, Elasticsearch, Kafka, InfluxDB, Qdrant, MinIO, PostGIS e
 Persistência Poliglota
================================================================================

 PRÉ-REQUISITOS:
 - Docker instalado
   >> Use: sudo apt install docker.io
   >> sudo systemctl start docker
 - Docker Compose (para 03_docker_compose.yml)
 - Para 09_poliglota.sh: MongoDB, Redis e Cassandra rodando

 ARQUIVOS:
    01_neo4j_cypher.sh
       Executa Neo4j via Docker e demonstra comandos Cypher:
       cria nós (Pessoa, Filme), relacionamentos (ASSISTIU, CONHECE)
       e consulta com MATCH. (Prova 4 - Q1, Q8)

    02_elasticsearch.sh
       Executa Elasticsearch via Docker e demonstra:
       criação de índice, indexação de documentos, consultas
       term, match e deleção via API REST (curl). (Prova 4 - Q5)

    03_docker_compose.yml
       Docker Compose que sobe todos os bancos estudados:
       MongoDB (27017), Redis (6379), Cassandra (9042) e
       Neo4j (7474/7687) com volumes persistentes.

    04_kafka_streaming.sh
       Kafka para streaming de eventos (publish-subscribe).
       Cria tópico, publica mensagens e consome eventos.
       Demonstra produtor, consumidor, partições e offsets.
       (Prova 4 - Q2)

    05_influxdb.sh
       InfluxDB para séries temporais (time-series).
       Insere métricas de CPU, memória e disco em intervalos
       de tempo e consulta com linguagem Flux.
       (Prova 4 - Q9)

    06_qdrant.sh
       Qdrant para busca vetorial (embeddings).
       Cria collection, insere vetores de filmes e faz busca
       por similaridade semântica com cosine distance.
       (Prova 4 - Q3)

    07_minio.sh
       MinIO para armazenamento de objetos (S3-compatible).
       Cria bucket, faz upload/download de arquivos e lista
       objetos com a CLI mc. (Prova 4 - Q4)

    08_postgis.sh
       PostGIS para dados geoespaciais.
       Cria tabelas com pontos e linhas, insere cidades e
       rodovias, consulta distâncias e interseções.
       (Prova 4 - Q6)

    09_poliglota.sh
       Persistência Poliglota — demonstração conceitual do
       uso de múltiplos bancos (MongoDB, Redis, Cassandra,
       Neo4j) em uma mesma aplicação de e-commerce.
       (Prova 4 - Q7)

 COMO EXECUTAR:
   chmod +x *.sh

   # Docker Compose (infra completa)
   docker compose -f 03_docker_compose.yml up -d

   # Neo4j
   ./01_neo4j_cypher.sh

   # Elasticsearch
   ./02_elasticsearch.sh

   # Kafka
   ./04_kafka_streaming.sh

   # InfluxDB
   ./05_influxdb.sh

   # Qdrant
   ./06_qdrant.sh

   # MinIO
   ./07_minio.sh

   # PostGIS
   ./08_postgis.sh

   # Persistência Poliglota
   ./09_poliglota.sh

   # Parar tudo
   docker compose -f 03_docker_compose.yml down

 PORTAS:
   MongoDB:   27017
   Redis:     6379
   Cassandra: 9042
   Neo4j:     7474 (http) / 7687 (bolt)
   Kafka:     9092
   InfluxDB:  8086
   Qdrant:    6333 (http) / 6334 (gRPC)
   MinIO:     9000 (api) / 9001 (console)
   PostGIS:   5432
================================================================================
