'use strict';

const express = require('express');
const router = express.Router();
const pool = require('../db');

// Wrapper para capturar erros assíncronos sem derrubar o processo
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

// POST /reservas — cria uma nova reserva
router.post('/', asyncHandler(async (req, res) => {
  const { cliente, data, status } = req.body || {};

  if (!cliente || !data) {
    return res.status(400).json({ error: 'Os campos "cliente" e "data" são obrigatórios.' });
  }

  const result = await pool.query(
    'INSERT INTO reservas (cliente, data, status) VALUES ($1, $2, $3) RETURNING *',
    [cliente, data, status || 'pendente']
  );

  return res.status(201).json(result.rows[0]);
}));

// GET /reservas — lista todas as reservas
router.get('/', asyncHandler(async (_req, res) => {
  const result = await pool.query('SELECT * FROM reservas ORDER BY id');
  return res.json(result.rows);
}));

// GET /reservas/:id — busca por ID
router.get('/:id', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const result = await pool.query('SELECT * FROM reservas WHERE id = $1', [id]);
  if (result.rowCount === 0) {
    return res.status(404).json({ error: 'Reserva não encontrada.' });
  }
  return res.json(result.rows[0]);
}));

// PUT /reservas/:id — atualiza uma reserva
router.put('/:id', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { cliente, data, status } = req.body || {};

  const current = await pool.query('SELECT * FROM reservas WHERE id = $1', [id]);
  if (current.rowCount === 0) {
    return res.status(404).json({ error: 'Reserva não encontrada.' });
  }

  const updated = await pool.query(
    `UPDATE reservas
     SET cliente = COALESCE($1, cliente),
         data    = COALESCE($2, data),
         status  = COALESCE($3, status)
     WHERE id = $4
     RETURNING *`,
    [cliente || null, data || null, status || null, id]
  );

  return res.json(updated.rows[0]);
}));

// DELETE /reservas/:id — remove uma reserva
router.delete('/:id', asyncHandler(async (req, res) => {
  const { id } = req.params;
  const result = await pool.query('DELETE FROM reservas WHERE id = $1', [id]);
  if (result.rowCount === 0) {
    return res.status(404).json({ error: 'Reserva não encontrada.' });
  }
  return res.status(204).send();
}));

module.exports = router;
