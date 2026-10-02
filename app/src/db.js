'use strict';

const { Pool, types } = require('pg');

// Retorna DATE como string 'YYYY-MM-DD' sem conversão de timezone
types.setTypeParser(1082, (val) => val);

const sslConfig = process.env.DB_SSL === 'true'
  ? { rejectUnauthorized: false }
  : false;

const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT || '5432', 10),
  user:     process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: process.env.POSTGRES_DB,
  ssl:      sslConfig,
});

module.exports = pool;
