# Setup — Banco de Dados II (EC2 AWS)

Scripts para instalar MongoDB 7, Redis e Cassandra 4.1 em uma instância EC2.

## SO compatível

Ubuntu 22.04 LTS, Ubuntu 24.04 LTS, Debian 12

## Scripts disponíveis

| Script | Instala |
|---|---|
| `setup_nosql.sh` | MongoDB 7 + Redis + Cassandra 4.1 |
| `setup_completo.sh` | Tudo do BD2 + Apache2 e exemplos de **Programação Web II** |

## Uso

```bash
chmod +x setup_nosql.sh          # ou setup_completo.sh
sudo ./setup_nosql.sh
```

Cada aluno tem sua própria EC2 e acessa os bancos localmente (dentro da instância):

- MongoDB:   `mongosh`
- Redis:     `redis-cli ping`
- Cassandra: `cqlsh`

## Security Group

Basta liberar a porta **22 (SSH)** para o IP de cada aluno.

Se for usar o `setup_completo.sh`, libere também a porta **80 (HTTP)**.
