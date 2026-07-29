# Banco de Dados II — Guia de Instalação (Debian 13)

**Professor:** Eduardo  
**Instância:** AWS EC2 m7i-flex.large — Debian 13 (Trixie)  
**Bancos:** MongoDB 7.0 + Redis + Cassandra 4.1

---

## 1. Enviar o script para sua EC2

No seu terminal local (Windows com PowerShell, Linux ou macOS):

```bash
scp -i /caminho/sua-chave.pem setup_debian13.sh usuario@<IP-DA-EC2>:
```

Substitua:
- `/caminho/sua-chave.pem` — caminho da sua chave SSH (.pem)
- `usuario` — `admin` (Debian) ou `ubuntu` (Ubuntu)
- `<IP-DA-EC2>` — IP público da sua instância

---

## 2. Conectar e instalar

```bash
ssh -i /caminho/sua-chave.pem usuario@<IP-DA-EC2>
chmod +x setup_debian13.sh
sudo ./setup_debian13.sh
```

O script leva de **5 a 10 minutos** para concluir. Ele instala:

| Banco     | Porta | Comando de acesso      |
|-----------|-------|------------------------|
| MongoDB   | 27017 | `mongosh`              |
| Redis     | 6379  | `redis-cli ping`       |
| Cassandra | 9042  | `cqlsh`                |

---

## 3. Verificar se tudo funciona

Após a instalação, teste cada banco:

```bash
# MongoDB
mongosh --eval "db.version()"

# Redis
redis-cli ping
# Deve responder: PONG

# Cassandra
cqlsh -e "DESCRIBE keyspaces;"
```

---

## 4. Copiar os exemplos da disciplina

Do seu computador local, envie a pasta de exemplos:

```bash
scp -i /caminho/sua-chave.pem -r "C:\Users\Eduardo\Downloads\Banco de Dados II\06_Exemplos_EC2" usuario@<IP-DA-EC2>:~/exemplos_banco2
```

Na EC2, acesse e execute os exemplos:

```bash
cd ~/exemplos_banco2

# Fundamentos (Teorema CAP, SQL vs NoSQL)
cd 01_Fundamentos
chmod +x *.sh
./01_teorema_cap.sh
./02_comparativo_sql_nosql.sh

# MongoDB (CRUD, aggregation, índices)
cd ../02_MongoDB
chmod +x *.sh
./01_crud_mongodb.sh
./02_aggregation.sh
./03_indices.sh

# Cassandra (CQL, modelagem)
cd ../03_Cassandra
chmod +x *.sh
cqlsh -f 01_crud_cassandra.cql
./02_modelagem_cql.sh

# Redis (estruturas, cache, fila)
cd ../04_Redis
chmod +x *.sh
./01_estruturas_redis.sh
./02_cache_simulacao.sh
./03_fila_redis.sh

# Projeto Integrador (MongoDB + Redis + Cassandra)
cd ../06_Projeto_Integrador
chmod +x *.sh
./01_ingestao_mongodb.sh
./02_cache_redis.sh
cqlsh -f 03_logs_cassandra.cql
```

---

## 5. Security Group (Firewall da AWS)

No console da AWS, para a EC2 de **cada aluno**, libere apenas:

| Porta | Serviço | Origem           |
|-------|---------|------------------|
| 22    | SSH     | IP do aluno      |

Os bancos ficam acessíveis apenas **dentro da própria EC2** (localhost).  
Não é necessário expor MongoDB, Redis ou Cassandra para a internet.

---

## 6. Problemas comuns

| Problema | Causa | Solução |
|----------|-------|---------|
| `mongosh: command not found` | MongoDB não está no PATH | Use `/opt/mongodb/bin/mongosh` ou rode `source /etc/profile.d/mongodb.sh` |
| `redis-cli ping` não responde | Redis não iniciou | `sudo systemctl restart redis-server` |
| `cqlsh: Connection refused` | Cassandra ainda está iniciando | Aguarde 2-3 minutos e tente novamente |
| Cassandra lento | Heap muito alto | Já ajustado para 1 GB no script |

---

## 7. Comandos úteis

```bash
# Status dos serviços
sudo systemctl status mongod
sudo systemctl status redis-server
sudo systemctl status cassandra

# Reiniciar um banco
sudo systemctl restart mongod
sudo systemctl restart redis-server
sudo systemctl restart cassandra

# Ver logs
sudo journalctl -u mongod --no-pager -n 20
sudo journalctl -u cassandra --no-pager -n 20
```