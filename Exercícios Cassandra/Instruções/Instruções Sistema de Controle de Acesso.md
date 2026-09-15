Sistema de Controle de Acesso e Auditoria de Segurança (Security Guard \& IAM).

Este sistema aborda dois conceitos fundamentais de segurança e autenticação:

1. Autenticação Segura (Hashing): Nunca salvamos senhas em texto puro. O script usará o utilitário nativo do Linux openssl (com o algoritmo SHA-256) para mascarar a senha antes de inseri-la no Cassandra.
2. Histórico de Auditoria Imutável (Log-Chain): Cada tentativa de login (com sucesso ou falha) será registrada em uma tabela de log temporal. No Cassandra, usar uma estrutura de chave composta por (usuario, timestamp) cria uma linha do tempo perfeita de quem tentou acessar o sistema, de onde (simulando um IP) e se obteve sucesso.



Como testar os recursos de segurança:

1. Salve o arquivo como sistema\_seguranca.sh e dê a permissão: chmod +x sistema\_seguranca.sh.
2. Rode o script: ./sistema\_seguranca.sh.
3. Escolha a Opção 1: Cadastre um usuário chamado admin com a senha 123456.
4. Escolha a Opção 2 (Autenticação):
- Faça um teste digitando admin e a senha errada (abcde). O sistema vai barrar.
- Faça outro teste digitando o usuário hacker (que nem existe). O sistema vai barrar.
- Por fim, faça o login informando as credenciais corretas. O sistema validará a correspondência dos hashes criptográficos e dará as boas-vindas.
5. Escolha a Opção 3 (Auditoria): Deixe o usuário em branco e aperte Enter. Você verá a trilha de logs imutável com as marcações de horário exatas de cada tentativa de login com sucesso ou falha, simulando IPs diferentes.

