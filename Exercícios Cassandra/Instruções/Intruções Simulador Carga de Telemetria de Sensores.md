Simulador de Telemetria de Sensores de Internet das Coisas (IoT).Este sistema foi desenhado exatamente para o que o Cassandra faz de melhor: escrita em altíssima velocidade. Em vez de cadastros individuais, ele gera dados randômicos simulando sensores de temperatura e pressão industriais enviando centenas de dados por segundo em um loop rápido em Bash. Para ficar bem visual, ele inclui um Menu Principal onde você inicia o gerador em massa e depois pode acompanhar um relatório de auditoria calculando as médias em tempo real.

Como realizar o Teste de Estresse:

1. Permissão e Execução: Salve como simulador\_carga\_cassandra.sh, dê permissão com chmod +x simulador\_carga\_cassandra.sh e rode: ./simulador\_carga\_cassandra.sh.
2. Inunde o Banco: Escolha a Opção 1. Você verá o terminal atualizar em blocos de 50 em 50 registros absurdamente rápido. Deixe rodando por uns 10 a 15 segundos para gerar alguns milhares de dados.
3. Pare a Carga: Aperte Ctrl + C. Como o script captura o comando, ele voltará para o seu terminal comum Debian.
4. Veja o Resultado: Execute o script novamente e entre na Opção 2 (Analytics). Você verá que o Cassandra absorveu toda aquela quantidade massiva de registros instantaneamente, ordenando tudo de forma decrescente pela coluna de tempo (horario DESC) sem engasgar.



Por que isso funciona tão bem no Cassandra?

Diferente dos bancos relacionais (como MySQL/Postgres) que sofrem travamentos (locks) e atualizações de índices complexos a cada inserção massiva, o Cassandra foi projetado na arquitetura LSM-Tree. Ele grava as informações primeiro diretamente na memória RAM (Memtable) e faz um append sequencial em disco (CommitLog). Isso faz com que a velocidade de escrita dele seja praticamente o limite de hardware da sua máquina Debian!

