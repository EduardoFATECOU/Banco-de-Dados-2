================================================================================
  BANCO DE DADOS II — SETUP DA INSTÂNCIA EC2
================================================================================

Este diretório contém os scripts necessários para configurar uma instância
AWS EC2 com todos os bancos de dados utilizados na disciplina.

SISTEMAS OPERACIONAIS SUPORTADOS:
  - Debian 12 (Bookworm)     — suporte apt completo ✅
  - Debian 13 (Trixie)       — MongoDB e Cassandra via Docker ⚠️
  - Ubuntu 22.04 (Jammy)     — suporte apt completo ✅
  - Ubuntu 24.04 (Noble)     — suporte apt completo ✅
  - Ubuntu 26.04+            — MongoDB via apt (repo noble compatível),
                                Cassandra via Docker ⚠️

  ⚠️ Cassandra só tem repositório oficial para Debian. No Ubuntu
     ele é instalado via Docker. MongoDB tem repo para ambos, mas
     versões muito novas do SO podem usar um repo compatível
     (ex: Ubuntu 26.04 usa o repo do 24.04 Noble).

--------------------------------------------------------------------------------
1. ENVIAR ARQUIVOS PARA A EC2 VIA SCP
--------------------------------------------------------------------------------

No seu terminal local (Windows, Linux ou macOS), execute:

    scp -i /caminho/sua-chave.pkg -r "C:\Users\Eduardo\Downloads\Banco de Dados II\06_Exemplos_EC2" \
        usuario@<IP-DA-EC2>:~/exemplos_banco2

Substitua:
  - /caminho/sua-chave.pkg  pelo caminho da sua chave SSH (.pem ou .ppk)
  - usuario                  pelo usuário da AMI (admin para Debian, ubuntu para Ubuntu)
  - <IP-DA-EC2>              pelo IP público da sua instância EC2

Exemplo:
    scp -i ~/chaves/aws.pem -r "C:\Users\Eduardo\Downloads\Banco de Dados II\06_Exemplos_EC2" \
        admin@54.123.45.67:~/exemplos_banco2

--------------------------------------------------------------------------------
2. EXECUTAR O SCRIPT DE INSTALAÇÃO
--------------------------------------------------------------------------------

Conecte-se via SSH e execute:

    ssh -i /caminho/sua-chave.pkg usuario@<IP-DA-EC2>

    cd ~/exemplos_banco2/00_Setup
    chmod +x instalar_tudo.sh
    sudo ./instalar_tudo.sh

O script irá:
  - Detectar automaticamente o SO (Debian ou Ubuntu)
  - Instalar Docker (usado como fallback quando não há repo apt)
  - Instalar MongoDB 7.0 (apt ou Docker)
  - Instalar Redis (apt)
  - Instalar Apache Cassandra (apt Debian / Docker Ubuntu)
  - Iniciar todos os serviços
  - Verificar se cada serviço está respondendo

ATENÇÃO: O script leva alguns minutos para concluir. Aguarde a verificação
final para confirmar que tudo está funcionando.

--------------------------------------------------------------------------------
3. PORTAS DE CADA SERVIÇO
--------------------------------------------------------------------------------

  MongoDB  → 27017 (TCP)
  Redis    → 6379  (TCP)
  Cassandra → 9042 (TCP)
  Neo4j    → 7474 (HTTP) e 7687 (Bolt)
  Elasticsearch → 9200 (HTTP)
  Docker   → socket UNIX /var/run/docker.sock

No console AWS, certifique-se de liberar essas portas no Security Group
da sua instância EC2 para o seu IP de origem.

--------------------------------------------------------------------------------
4. COMANDOS RÁPIDOS DE VERIFICAÇÃO
--------------------------------------------------------------------------------

  MongoDB:   mongosh --eval "db.version()"           # apt
             docker exec -it mongodb mongosh ...      # Docker
  Redis:     redis-cli ping
  Cassandra: cqlsh -e "DESCRIBE keyspaces;"           # apt
             docker exec -it cassandra cqlsh ...      # Docker
  Docker:    docker run --rm hello-world

--------------------------------------------------------------------------------
5. ACESSO AOS EXEMPLOS
--------------------------------------------------------------------------------

Cada subdiretório contém scripts organizados por tópico:

  00_Setup           → Scripts de instalação (este diretório)
  01_Fundamentos     → Teorema CAP, comparativo SQL vs NoSQL
  02_MongoDB         → CRUD, aggregation, índices
  03_Cassandra       → CRUD CQL, modelagem orientada a consultas
  04_Redis           → Estruturas, cache, fila de tarefas
  05_Outros_Modelos  → Neo4j, Elasticsearch, Kafka, InfluxDB, Qdrant, MinIO, PostGIS e Poliglota
  06_Projeto_Integrador → Catálogo de filmes (MongoDB + Redis + Cassandra)

Para servir a página HTML via Python (opcional):

    cd ~/exemplos_banco2
    python3 -m http.server 8080

Acesse: http://<IP-DA-EC2>:8080

================================================================================
