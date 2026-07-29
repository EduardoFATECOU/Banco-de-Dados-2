================================================================================
 PASTA: 01_Fundamentos - Banco de Dados II
 Exemplso sobre o Teorema CAP e comparativo SQL vs NoSQL
================================================================================

 PRÉ-REQUISITOS:
 - Nenhum. Estes scripts são apenas demonstrativos (não precisam de banco).

 ARQUIVOS:
   01_teorema_cap.sh
      Demonstração interativa do Teorema CAP (Consistência, Disponibilidade,
      Tolerância a Partição). Exibe os trade-offs e exemplos de bancos
      em cada categoria (CA, CP, AP).

   02_comparativo_sql_nosql.sh
      Compara abordagens SQL e NoSQL para o mesmo problema.
      Cria dados CSV, simula consultas SQL (SELECT, JOIN) e
      mostra como o mesmo dado seria modelado em MongoDB (JSON).

 COMO EXECUTAR:
   chmod +x *.sh
   ./01_teorema_cap.sh
   ./02_comparativo_sql_nosql.sh

 DICA PEDAGÓGICA:
   Execute o teorema_cap.sh primeiro para introduzir o conceito,
   depois o comparativo para mostrar a diferença prática entre
   os paradigmas relacional e não relacional.
================================================================================
