'use strict';

const express = require('express');
const pool    = require('./db');

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// ── Inicializa a tabela reservas se não existir ─────────────────────────────
async function initDB() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS reservas (
      id        SERIAL PRIMARY KEY,
      cliente   TEXT        NOT NULL,
      data      DATE        NOT NULL,
      status    TEXT        NOT NULL DEFAULT 'pendente',
      criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  console.log('Tabela "reservas" pronta.');
}

// ── Rotas ───────────────────────────────────────────────────────────────────
const reservasRouter = require('./routes/reservas');
app.use('/reservas', reservasRouter);

// GET /health — verifica conexão com o banco
app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    return res.json({ status: 'healthy', db: 'connected', uptime: process.uptime() });
  } catch (err) {
    return res.status(503).json({ status: 'unhealthy', db: 'disconnected', error: err.message });
  }
});

// ── Inicia servidor após garantir que o banco está pronto ───────────────────
(async () => {
  try {
    await initDB();
    app.listen(PORT, () => {
      console.log(`TechNova API rodando na porta ${PORT}`);
    });
  } catch (err) {
    console.error('Erro ao conectar/inicializar banco:', err.message);
    process.exit(1);
  }
})();
