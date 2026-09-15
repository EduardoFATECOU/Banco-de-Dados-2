Sistema de Mensagens Autodestrutivas (Estilo Snapchat/Missão Impossível).No Cassandra, você pode definir um tempo em segundos para qualquer registro. Quando esse tempo expira, o próprio banco de dados apaga o registro de forma automática e permanente, sem que você precise rodar nenhum script de limpeza! Este script cria um sistema onde você envia uma mensagem criptografada (usando base64 do próprio Linux), define quantos segundos ela deve durar e, após esse tempo, ela desaparece do banco de dados para sempre. 

Como testar a mágica do Cassandra:

1. Salve o código em um arquivo (ex: mensagens\_secretas.sh).
2. Dê permissão e execute: chmod +x mensagens\_secretas.sh \&\& ./mensagens\_secretas.sh
3. Escolha a Opção 1 para criar uma mensagem. Diga que ela deve durar apenas 20 segundos.
4. Corra para a Opção 3 (ou Opção 2) e veja que ela está lá e mostra o tempo em contagem regressiva.
5. Espere os 20 segundos passarem e consulte a lista novamente. Ela sumiu sozinha do banco de dados, sem você precisar fazer nada!

