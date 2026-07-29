#!/usr/bin/env bash
# =============================================================================
# Demonstração de índices no MongoDB
# Database: teste_indices | Coleção: logs
#
# Índices aceleram consultas, mas ocupam espaço e podem deixar escritas
# mais lentas. Este script mostra a diferença de performance.
#
# Uso: chmod +x 03_indices.sh && ./03_indices.sh
# Requer: mongosh instalado e MongoDB rodando
# =============================================================================

set -e

echo "================================================================"
echo "  MONGODB — Índices e Performance"
echo "  Database: teste_indices | Coleção: logs"
echo "================================================================"
echo ""

mongosh << 'EOF'
print("================================================================");
print("  1. Inserindo 10.000 documentos de log...");
print("================================================================");

use("teste_indices");
db.logs.drop();  // Limpa coleção anterior

const usuarios = ["joao", "maria", "carlos", "ana", "pedro", "lucia", "rafael", "julia"];
const acoes = ["login", "logout", "compra", "venda", "cancelamento", "cadastro"];

const docs = [];
for (let i = 0; i < 10000; i++) {
    docs.push({
        usuario: usuarios[Math.floor(Math.random() * usuarios.length)],
        acao: acoes[Math.floor(Math.random() * acoes.length)],
        valor: Math.random() * 1000,
        data: new Date(2025, Math.floor(Math.random() * 12), Math.floor(Math.random() * 28) + 1),
        ip: "192.168." + Math.floor(Math.random() * 255) + "." + Math.floor(Math.random() * 255),
        duracao: Math.floor(Math.random() * 5000) + 100
    });
}

db.logs.insertMany(docs);
print("Inseridos " + db.logs.countDocuments() + " documentos de log.\n");

// ==========================================================================
// 2. CONSULTA SEM ÍNDICE
// ==========================================================================
print("================================================================");
print("  2. Consulta SEM índice...");
print("================================================================");

// Explica o plano de execução
const semIndice = db.logs.find({ usuario: "ana" }).explain("executionStats");

const totalDocsExaminedSemIndice = semIndice.executionStats.totalDocsExamined;
const tempoSemIndice = semIndice.executionStats.executionTimeMillis;

print("  Campo pesquisado: 'usuario' (sem índice)");
print("  Documentos examinados: " + totalDocsExaminedSemIndice + " (de 10000)");
print("  Tempo de execução: " + tempoSemIndice + "ms");
print("  Estratégia: COLLSCAN (varredura completa da coleção)");
print("");

// ==========================================================================
// 3. CRIAR ÍNDICE
// ==========================================================================
print("================================================================");
print("  3. Criando índice no campo 'usuario'...");
print("================================================================");

// Cria índice ascendente (1) no campo usuario
db.logs.createIndex({ usuario: 1 });
print("  Índice criado: { usuario: 1 } (ascendente)");
print("");

// Lista todos os índices da coleção
print("Índices existentes:");
db.logs.getIndexes().forEach(idx => {
    print("  " + JSON.stringify(idx));
});
print("");

// ==========================================================================
// 4. CONSULTA COM ÍNDICE
// ==========================================================================
print("================================================================");
print("  4. Consulta COM índice...");
print("================================================================");

const comIndice = db.logs.find({ usuario: "ana" }).explain("executionStats");
const totalDocsExaminedComIndice = comIndice.executionStats.totalDocsExamined;
const tempoComIndice = comIndice.executionStats.executionTimeMillis;

print("  Campo pesquisado: 'usuario' (com índice)");
print("  Documentos examinados: " + totalDocsExaminedComIndice + " (apenas os que correspondem)");
print("  Tempo de execução: " + tempoComIndice + "ms");
print("  Estratégia: IXSCAN (varredura por índice)");
print("");

// ==========================================================================
// 5. COMPARAÇÃO DE PERFORMANCE
// ==========================================================================
print("================================================================");
print("  5. COMPARAÇÃO: Com índice vs Sem índice");
print("================================================================");

const fatorMelhora = tempoSemIndice > 0 ? (tempoSemIndice / (tempoComIndice || 1)).toFixed(1) : "N/A";

print("  +---------------------+------------+------------+");
print("  | Métrica             | Sem índice | Com índice |");
print("  +---------------------+------------+------------+");
print("  | Documentos examin.  | " +
      totalDocsExaminedSemIndice.toString().padStart(8) + "  | " +
      totalDocsExaminedComIndice.toString().padStart(8) + "  |");
print("  | Tempo de execução   | " +
      tempoSemIndice.toString().padStart(8) + "ms | " +
      tempoComIndice.toString().padStart(8) + "ms |");
print("  +---------------------+------------+------------+");

if (fatorMelhora !== "N/A") {
    print("\n  O índice tornou a consulta " + fatorMelhora + "x mais rápida!\n");
}

// ==========================================================================
// 6. ÍNDICE COMPOSTO
// ==========================================================================
print("================================================================");
print("  6. Criando índice composto (usuario + data)...");
print("================================================================");

db.logs.createIndex({ usuario: 1, data: -1 });
print("  Índice composto criado: { usuario: 1, data: -1 }");
print("");

print("--- Consulta que usa índice composto ---");
const composto = db.logs.find(
    { usuario: "maria", data: { $gte: new Date("2025-06-01") } }
).sort({ data: -1 }).explain("executionStats");
print("  Documentos examinados: " + composto.executionStats.totalDocsExamined);
print("  Tempo: " + composto.executionStats.executionTimeMillis + "ms");
print("  Índice usado: " + (composto.queryPlanner.winningPlan.inputStage ?
        composto.queryPlanner.winningPlan.inputStage.indexName :
        composto.queryPlanner.winningPlan.indexName));
print("");

// ==========================================================================
// 7. DICAS SOBRE ÍNDICES
// ==========================================================================
print("================================================================");
print("  DICAS SOBRE ÍNDICES");
print("================================================================");
print("");
print("  - Índices aceleram READ, mas podem tornar INSERT/UPDATE mais lentos");
print("  - Use índices apenas em campos consultados com frequência");
print("  - Índices compostos funcionam para consultas que usam prefixos");
print("  - getIndexes() lista todos os índices da coleção");
print("  - dropIndex() remove um índice específico");
print("  - O tamanho do índice pode ser visto com db.logs.totalIndexSize()");
print("");
print("Tamanho total dos índices: " + db.logs.totalIndexSize() + " bytes");
print("");

print("================================================================");
print("  Demonstração de índices concluída!");
print("================================================================");

// Limpa os dados de exemplo
// db.logs.drop();  // Descomente se quiser limpar ao final
EOF

echo "Script finalizado."
