import assert from 'node:assert/strict';
import { readdir, readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { PGlite } from '@electric-sql/pglite';

const root = new URL('../', import.meta.url);
const sql = async path => readFile(new URL(path, root), 'utf8');

test('Supabase foundation enforces privacy, roles and immutable workflow fields', async () => {
  const database = new PGlite();
  try {
    // This fixture substitutes managed Supabase schemas only in memory. It cannot
    // verify Auth, Storage API, pooling or the configuration of a hosted project.
    await database.exec(await sql('tests/database/fixture.sql'));
    const migrations = (await readdir(new URL('supabase/migrations/', root)))
      .filter(name => name.endsWith('.sql')).sort();
    assert.ok(migrations.length, 'At least one migration must exist');
    for (const migration of migrations) {
      await database.exec(await sql(`supabase/migrations/${migration}`));
    }
    const seed = await sql('supabase/seed.sql');
    await database.exec(seed);
    await database.exec(seed);
    const results = await database.exec(await sql('tests/database/foundation.sql'));
    const report = results.find(result => result.rows[0]?.assertions_passed !== undefined);
    assert.ok(report, 'SQL suite must report its assertion count');
    assert.ok(report.rows[0].assertions_passed > 0);
    console.info(`${report.rows[0].assertions_passed} database security assertions passed`);
  } catch (error) {
    // PGlite attaches the entire SQL suite to errors; keep CI output actionable.
    throw new Error(`${error.message}${error.code ? ` [${error.code}]` : ''}${error.where ? `\n${error.where}` : ''}`);
  } finally {
    await database.close();
  }
});
