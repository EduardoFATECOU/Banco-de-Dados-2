================================================================================
 PASTA: 02_MongoDB - Banco de Dados II
 Exemplos de CRUD, Agregação e Índices no MongoDB
================================================================================

 PRÉ-REQUISITOS:
 - MongoDB instalado e rodando (mongod)
   >> Use: sudo systemctl start mongod
 - mongosh instalado (vem com o MongoDB)

 ARQUIVOS:
   01_crud_mongodb.sh
      CRUD básico: cria database "escola", coleção "alunos",
      insere 5 alunos, faz consultas com filtros, atualiza
      notas e deleta registros.

   02_aggregation.sh
      Pipeline de agregação: cria coleção "vendas" com 15
      documentos e executa pipeline com $match, $group,
      $sort, $project e $out.

   03_indices.sh
      Demonstração de índices: insere 10.000 documentos,
      cria índice e compara performance com/ sem índice
      usando explain().

 COMO EXECUTAR:
   chmod +x *.sh
   ./01_crud_mongodb.sh
   ./02_aggregation.sh
   ./03_indices.sh

 ORDEM RECOMENDADA:
   1. 01_crud_mongodb.sh  (conceitos básicos)
   2. 02_aggregation.sh   (consulta avançada)
   3. 03_indices.sh       (otimização)

 DICA: Para ver os dados no MongoDB Compass, acesse:
   mongodb://localhost:27017
================================================================================
