# Banco de Dados II

Repositório oficial da disciplina **Banco de Dados II** — Professor Eduardo.

## Conteúdo

| Pasta | Descrição |
|---|---|
| `00_Setup/` | Script de instalação (Docker + MongoDB + Redis + Cassandra) |
| `01_Fundamentos/` | Teoria: Teorema CAP, Comparativo SQL × NoSQL |
| `02_MongoDB/` | CRUD, Aggregation Pipeline, Índices |
| `03_Cassandra/` | CQL básico, Modelagem Query-First |
| `04_Redis/` | Estruturas de dados, Cache, Fila de tarefas |
| `05_Outros_Modelos/` | Neo4j, Elasticsearch, Kafka, Qdrant |
| `06_Projeto_Integrador/` | Projeto final integrando MongoDB + Redis + Cassandra |
| `Para Aula/` | Guia do aluno para configurar a EC2 |

## Pré-requisitos

- AWS EC2 com **Debian 13 (Trixie)** — tipo `m7i-flex.large` (8 GB de disco)
- Acesso SSH com chave `.pem`

## Setup rápido

```bash
# Conecte na EC2
ssh -i sua-chave.pem admin@<IP-DA-EC2>

# Envie o script de setup
scp -i sua-chave.pem 00_Setup/setup_docker.sh admin@<IP>:~/

# Execute (como root)
chmod +x setup_docker.sh
sudo ./setup_docker.sh

# Teste
mongosh --eval "db.version()"
redis-cli ping
cqlsh -e "DESCRIBE keyspaces;"
```

## Copiar os exemplos para a EC2

```bash
# No seu computador:
scp -i sua-chave.pem -r "06_Exemplos_EC2" admin@<IP>:~/exemplos_banco2
```

## Executar os exemplos

```bash
cd ~/exemplos_banco2

# Fundamentos
cd 01_Fundamentos && ./01_teorema_cap.sh

# MongoDB
cd ../02_MongoDB && ./01_crud_mongodb.sh

# Cassandra (usar pipe: cqlsh roda dentro do container)
cd ../03_Cassandra
cat 01_crud_cassandra.cql | cqlsh
./02_modelagem_cql.sh

# Redis
cd ../04_Redis && ./01_estruturas_redis.sh

# Projeto Integrador
cd ../06_Projeto_Integrador
./01_ingestao_mongodb.sh
cat 03_logs_cassandra.cql | cqlsh
```

## Gerenciar containers

```bash
cd /opt/banco2
docker compose ps      # Status
docker compose down    # Parar tudo
docker compose up -d   # Iniciar tudo
```

## Solução de problemas comuns

| Problema | Solução |
|---|---|
| `Connection refused` nos bancos | `cd /opt/banco2 && docker compose up -d` |
| `Container name already in use` | `docker rm -f mongodb_banco2 redis_banco2 cassandra_banco2` |
| `No space left on device` | `docker system prune -a -f && sudo apt-get clean` |
| Cassandra demorando | Aguarde 2-3 min, depois `cqlsh` |
| `command not found: mongosh` | Execute `sudo ./setup_docker.sh` novamente |

> **Nota:** A EC2 tem apenas **8 GB de disco**. Os scripts já incluem limpeza automática no início.

## Licença

Material didático para uso acadêmico.