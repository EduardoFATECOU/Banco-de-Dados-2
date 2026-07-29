#!/usr/bin/env bash
# =============================================================================
# Demonstração do Teorema CAP (Brewer's Theorem)
# Script educativo que explica os conceitos de Consistência, Disponibilidade
# e Tolerância a Partições com exemplos práticos.
#
# Uso: chmod +x 01_teorema_cap.sh && ./01_teorema_cap.sh
# =============================================================================

# Limpa a tela para começar a apresentação
clear

echo "================================================================"
echo "  TEOREMA CAP (Brewer's Theorem)"
echo "  Eric Brewer — 2000"
echo "================================================================"
echo ""

sleep 2

echo "O Teorema CAP afirma que um sistema distribuído de armazenamento"
echo "pode garantir apenas 2 das 3 propriedades a seguir:"
echo ""
sleep 1
echo "  C — Consistência (Consistency)"
echo "      Todos os nós enxergam os mesmos dados ao mesmo tempo."
echo ""
sleep 1
echo "  A — Disponibilidade (Availability)"
echo "      Cada requisição recebe uma resposta (com sucesso ou falha)."
echo ""
sleep 1
echo "  P — Tolerância a Partições (Partition Tolerance)"
echo "      O sistema continua operando mesmo com falhas de rede."
echo ""
sleep 2

echo "================================================================"
echo "  COMBINAÇÕES POSSÍVEIS"
echo "================================================================"
echo ""
sleep 1

echo "  CA — Consistência + Disponibilidade"
echo "       Sistemas monolíticos relacionais (MySQL, PostgreSQL)."
echo "       Não toleram partições de rede."
echo ""
sleep 1

echo "  CP — Consistência + Tolerância a Partições"
echo "       MongoDB (configuração padrão), HBase, Redis (modo cluster)."
echo "       Priorizam dados corretos mesmo que o sistema fique indisponível."
echo ""
sleep 1

echo "  AP — Disponibilidade + Tolerância a Partições"
echo "       Cassandra, CouchDB, DynamoDB."
echo "       Priorizam responder sempre, mesmo que dados estejam"
echo "       temporariamente inconsistentes (consistência eventual)."
echo ""
sleep 2

echo "================================================================"
echo "  EXEMPLO PRÁTICO: SISTEMA DE RESERVAS"
echo "================================================================"
echo ""

# Simula cenário de partição de rede com sleep e echo
echo "Cenário: Dois servidores (SP e RJ) com uma partição de rede entre eles."
echo ""

sleep 2

echo "--- Abordagem CP (MongoDB) ---"
echo "  Cliente no RJ tenta reservar o último ingresso."
echo "  O nó SP está com o dado atualizado, mas RJ não consegue"
echo "  se comunicar com SP."
echo "  RESULTADO: A operação é recusada (indisponibilidade)"
echo "            para garantir que não haja duplicidade."
echo ""
sleep 2

echo "--- Abordagem AP (Cassandra) ---"
echo "  Cliente no RJ tenta reservar o último ingresso."
echo "  RJ aceita a reserva mesmo sem conseguir falar com SP."
echo "  RESULTADO: A reserva é aceita (disponibilidade mantida)."
echo "            Se dois clientes reservaram ao mesmo tempo,"
echo "            a consistência será resolvida depois (eventual)."
echo ""
sleep 2

echo "================================================================"
echo "  RESUMO — ESCOLHA DO BANCO DE DADOS"
echo "================================================================"
echo ""
sleep 1

cat << Tabela
  +----------------+--------+--------+--------+
  | Banco          |   C    |   A    |   P    |
  +----------------+--------+--------+--------+
  | MySQL/Postgres |  SIM   |  SIM   |  NÃO   |
  | MongoDB        |  SIM   |  NÃO   |  SIM   |
  | Cassandra      |  NÃO   |  SIM   |  SIM   |
  | Redis          |  SIM   |  NÃO   |  SIM   |
  | DynamoDB       |  NÃO   |  SIM   |  SIM   |
  +----------------+--------+--------+--------+

  * Consistência Eventual: dados ficam consistentes com o tempo.
  * Consistência Forte: dados são idênticos em todos os nós
    imediatamente após a escrita.

Tabela

sleep 3

echo ""
echo "================================================================"
echo "  CONCLUSÃO"
echo "================================================================"
echo ""
echo "Não existe banco de dados 'melhor' — a escolha depende"
echo "dos requisitos do seu sistema:"
echo ""
echo "  - Sistema bancário precisa de CA (consistência forte)"
echo "  - Rede social pode usar AP (disponibilidade total)"
echo "  - Catálogo de produtos pode usar CP"
echo ""
echo "O Teorema CAP ajuda a entender esses trade-offs."
echo ""
echo "Fim da demonstração."
