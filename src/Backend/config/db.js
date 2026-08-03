const { PrismaClient } = require('@prisma/client');
const { Pool } = require('pg');
const logger = require('../core/logger');

// Prisma ORM client
const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development'
    ? ['query', 'info', 'warn', 'error']
    : ['error'],
});

// Native pg Pool (for raw queries, health checks)
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  logger.error('PostgreSQL pool error', { error: err.message });
});

// Verify DB connection
async function verifyConnection() {
  try {
    await prisma.$connect();
    const result = await pool.query('SELECT current_database() AS db, version() AS version');
    logger.info('PostgreSQL connected', {
      database: result.rows[0].db,
      version: result.rows[0].version,
    });
    return true;
  } catch (error) {
    logger.error('PostgreSQL connection failed', { error: error.message });
    throw error;
  }
}

module.exports = { prisma, pool, verifyConnection };
