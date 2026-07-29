#!/usr/bin/env bash
# =============================================================================
# Projeto Integrador — Ingestão de dados no MongoDB
#
# Popula o database "filmes" com 20 filmes do catálogo.
# Cada documento contém: titulo, ano, genero, diretor, nota, duracao, elenco.
#
# Uso: chmod +x 01_ingestao_mongodb.sh && ./01_ingestao_mongodb.sh
# Requer: mongosh instalado e MongoDB rodando
# =============================================================================

set -e

echo "================================================================"
echo "  PROJETO INTEGRADOR — Ingestão de Filmes no MongoDB"
echo "  Database: filmes | Coleção: catalogo"
echo "================================================================"
echo ""

mongosh << 'EOF'
// ==========================================================================
// 1. Criar database e coleção
// ==========================================================================
print(">>> Criando database 'filmes' e inserindo catálogo...\n");

use("filmes");

// Limpa dados anteriores
db.catalogo.drop();

// ==========================================================================
// 2. Inserir 20 filmes
// ==========================================================================
db.catalogo.insertMany([
    {
        titulo: "Matrix",
        ano: 1999,
        genero: "Ficção Científica",
        diretor: "Lana Wachowski, Lilly Wachowski",
        nota: 8.7,
        duracao: 136,
        elenco: ["Keanu Reeves", "Laurence Fishburne", "Carrie-Anne Moss"]
    },
    {
        titulo: "O Poderoso Chefão",
        ano: 1972,
        genero: "Drama",
        diretor: "Francis Ford Coppola",
        nota: 9.2,
        duracao: 175,
        elenco: ["Marlon Brando", "Al Pacino", "James Caan"]
    },
    {
        titulo: "Interestelar",
        ano: 2014,
        genero: "Ficção Científica",
        diretor: "Christopher Nolan",
        nota: 8.7,
        duracao: 169,
        elenco: ["Matthew McConaughey", "Anne Hathaway", "Jessica Chastain"]
    },
    {
        titulo: "Clube da Luta",
        ano: 1999,
        genero: "Drama",
        diretor: "David Fincher",
        nota: 8.8,
        duracao: 139,
        elenco: ["Brad Pitt", "Edward Norton", "Helena Bonham Carter"]
    },
    {
        titulo: "Pulp Fiction",
        ano: 1994,
        genero: "Crime",
        diretor: "Quentin Tarantino",
        nota: 8.9,
        duracao: 154,
        elenco: ["John Travolta", "Samuel L. Jackson", "Uma Thurman"]
    },
    {
        titulo: "Forrest Gump",
        ano: 1994,
        genero: "Drama",
        diretor: "Robert Zemeckis",
        nota: 8.8,
        duracao: 142,
        elenco: ["Tom Hanks", "Robin Wright", "Gary Sinise"]
    },
    {
        titulo: "O Senhor dos Anéis: O Retorno do Rei",
        ano: 2003,
        genero: "Fantasia",
        diretor: "Peter Jackson",
        nota: 9.0,
        duracao: 201,
        elenco: ["Elijah Wood", "Viggo Mortensen", "Ian McKellen"]
    },
    {
        titulo: "O Cavaleiro das Trevas",
        ano: 2008,
        genero: "Ação",
        diretor: "Christopher Nolan",
        nota: 9.0,
        duracao: 152,
        elenco: ["Christian Bale", "Heath Ledger", "Aaron Eckhart"]
    },
    {
        titulo: "A Origem",
        ano: 2010,
        genero: "Ficção Científica",
        diretor: "Christopher Nolan",
        nota: 8.8,
        duracao: 148,
        elenco: ["Leonardo DiCaprio", "Joseph Gordon-Levitt", "Elliot Page"]
    },
    {
        titulo: "Parasita",
        ano: 2019,
        genero: "Drama",
        diretor: "Bong Joon-ho",
        nota: 8.5,
        duracao: 132,
        elenco: ["Kang-ho Song", "Sun-kyun Lee", "Yeo-jeong Jo"]
    },
    {
        titulo: "De Volta para o Futuro",
        ano: 1985,
        genero: "Ficção Científica",
        diretor: "Robert Zemeckis",
        nota: 8.5,
        duracao: 116,
        elenco: ["Michael J. Fox", "Christopher Lloyd", "Lea Thompson"]
    },
    {
        titulo: "O Silêncio dos Inocentes",
        ano: 1991,
        genero: "Suspense",
        diretor: "Jonathan Demme",
        nota: 8.6,
        duracao: 118,
        elenco: ["Jodie Foster", "Anthony Hopkins", "Scott Glenn"]
    },
    {
        titulo: "Toy Story",
        ano: 1995,
        genero: "Animação",
        diretor: "John Lasseter",
        nota: 8.3,
        duracao: 81,
        elenco: ["Tom Hanks", "Tim Allen", "Don Rickles"]
    },
    {
        titulo: "Gladiador",
        ano: 2000,
        genero: "Ação",
        diretor: "Ridley Scott",
        nota: 8.5,
        duracao: 155,
        elenco: ["Russell Crowe", "Joaquin Phoenix", "Connie Nielsen"]
    },
    {
        titulo: "Cidade de Deus",
        ano: 2002,
        genero: "Crime",
        diretor: "Fernando Meirelles, Kátia Lund",
        nota: 8.6,
        duracao: 130,
        elenco: ["Alexandre Rodrigues", "Leandro Firmino", "Phellipe Haagensen"]
    },
    {
        titulo: "Star Wars: O Império Contra-Ataca",
        ano: 1980,
        genero: "Ficção Científica",
        diretor: "Irvin Kershner",
        nota: 8.7,
        duracao: 124,
        elenco: ["Mark Hamill", "Harrison Ford", "Carrie Fisher"]
    },
    {
        titulo: "O Grande Lebowski",
        ano: 1998,
        genero: "Comédia",
        diretor: "Joel Coen",
        nota: 8.1,
        duracao: 117,
        elenco: ["Jeff Bridges", "John Goodman", "Julianne Moore"]
    },
    {
        titulo: "Coringa",
        ano: 2019,
        genero: "Drama",
        diretor: "Todd Phillips",
        nota: 8.4,
        duracao: 122,
        elenco: ["Joaquin Phoenix", "Robert De Niro", "Zazie Beetz"]
    },
    {
        titulo: "O Resgate do Soldado Ryan",
        ano: 1998,
        genero: "Guerra",
        diretor: "Steven Spielberg",
        nota: 8.6,
        duracao: 169,
        elenco: ["Tom Hanks", "Matt Damon", "Tom Sizemore"]
    },
    {
        titulo: "Whiplash",
        ano: 2014,
        genero: "Drama",
        diretor: "Damien Chazelle",
        nota: 8.5,
        duracao: 106,
        elenco: ["Miles Teller", "J.K. Simmons", "Melissa Benoist"]
    }
]);

print("================================================================");
print("  RESULTADO DA INGESTÃO");
print("================================================================");
print("");
print("Total de filmes inseridos: " + db.catalogo.countDocuments());
print("");

// ==========================================================================
// 3. Consultas de verificação
// ==========================================================================
print("--- 5 filmes com maior nota ---");
db.catalogo.find().sort({ nota: -1 }).limit(5).forEach(function(f) {
    print("  " + f.titulo + " (" + f.ano + ") — Nota: " + f.nota);
});

print("");
print("--- Filmes de Christopher Nolan ---");
db.catalogo.find({ diretor: "Christopher Nolan" }).forEach(function(f) {
    print("  " + f.titulo + " (" + f.ano + ") — " + f.genero);
});

print("");
print("--- Filmes de Ficção Científica ---");
db.catalogo.find({ genero: "Ficção Científica" }).forEach(function(f) {
    print("  " + f.titulo + " (" + f.ano + ") — Diretor: " + f.diretor);
});

print("");
print("--- Estatísticas do catálogo ---");
const stats = db.catalogo.aggregate([
    {
        $group: {
            _id: null,
            mediaNota: { $avg: "$nota" },
            filmeMaisAntigo: { $min: "$ano" },
            filmeMaisNovo: { $max: "$ano" },
            totalFilmes: { $sum: 1 }
        }
    }
]).next();

print("  Média das notas: " + stats.mediaNota.toFixed(2));
print("  Período: " + stats.filmeMaisAntigo + " a " + stats.filmeMaisNovo);
print("  Total de filmes: " + stats.totalFilmes);

print("");
print("================================================================");
print("  Ingestão concluída! Catálogo pronto para uso.");
print("================================================================");
EOF
