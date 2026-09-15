Sistema de Análise Financeira e Cálculo de Volatilidade de Ações (Algorithmic Trading Analytics).

Neste cenário, vamos simular o mercado financeiro. O script vai gerar variações de preços para ativos (como PETR4 ou VALE3), salvar no Cassandra e aplicar fórmulas matemáticas via Bash e CQL para calcular:

1. O Retorno Percentual Diário (Lógica de variação entre preço de abertura e fechamento).
2. A Média Móvel Simples (SMA) (Média matemática dos últimos preços cadastrados).
3. A Volatilidade Histórica (Amplitude) (A diferença percentual entre a máxima e a mínima do dia para medir o risco).



Para fazer os cálculos de ponto flutuante (números decimais) com precisão no Bash, utilizaremos a ferramenta padrão do Linux chamada bc (Basic Calculator).



Como testar as fórmulas matemáticas:

1. Salve o arquivo como analytics\_financeiro.sh e dê permissão de execução: chmod +x analytics\_financeiro.sh.
2. Rode o script: ./analytics\_financeiro.sh.
3. Escolha a Opção 1: Digite PETR4 e dê um valor inicial, ex: 34.50. O script usará equações matemáticas para forjar 5 dias de mercado coerentes (calculando máximas e mínimas lógicas para cada dia e usando o preço de fechamento como abertura do dia seguinte).
4. Escolha a Opção 2: Digite PETR4. O Bash irá extrair o bloco de dados brutos do Cassandra e aplicar as fórmulas de Média Móvel, Amplitude de Risco e Retorno Percentual usando o motor matemático bc do Linux.

