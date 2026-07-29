================================================================================
 PASTA: 03_Cassandra - Banco de Dados II
 Exemplos de CQL e modelagem orientada a consultas no Cassandra
================================================================================

 PRÉ-REQUISITOS:
 - Apache Cassandra instalado e rodando
   >> Use: sudo systemctl start cassandra
 - cqlsh instalado (vem com o Cassandra)

 ARQUIVOS:
   01_crud_cassandra.cql
      CRUD básico em CQL: cria keyspace "loja", tabela
      "produtos", insere registros, consulta com WHERE,
      atualiza preço e deleta.

   02_modelagem_cql.sh
      Demonstra modelagem orientada a consultas (Query First):
      cria keyspace "biblioteca" com tabelas modeladas para
      consultas específicas (por autor, por ano, por categoria)
      e explica porque cada tabela foi criada daquela forma.

 COMO EXECUTAR:
   chmod +x *.sh

   # Opcao 1: via pipe (cqlsh roda dentro do container Docker)
   cat 01_crud_cassandra.cql | cqlsh

   # Opcao 2: via script
   ./02_modelagem_cql.sh

 OBS: O arquivo .cql pode ser editado e executado linha a linha
   no cqlsh interativo. Basta copiar e colar os comandos.

 DICA PEDAGÓGICA:
   O Cassandra modela tabelas pensando primeiro na consulta
   (Query First). Diferente do SQL, a normalização não é
   prioridade - a performance da leitura é o foco.
================================================================================
