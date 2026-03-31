const { getDb } = require('../config/database');

async function createProfile({ householdId, name, email }) {
  const db = await getDb();

  const household = await db.get('SELECT id FROM households WHERE id = ?', householdId);
  if (!household) {
    throw Object.assign(new Error('Household not found'), { status: 404 });
  }

  const result = await db.run(
    'INSERT INTO profiles (household_id, name, email) VALUES (?, ?, ?)',
    householdId, name, email || null
  );

  return db.get('SELECT * FROM profiles WHERE id = ?', result.lastID);
}

async function listProfiles(householdId) {
  const db = await getDb();
  return db.all(
    'SELECT id, household_id, name, email, created_at FROM profiles WHERE household_id = ? ORDER BY name',
    householdId
  );
}

async function getProfile(id) {
  const db = await getDb();
  const profile = await db.get('SELECT * FROM profiles WHERE id = ?', id);
  if (!profile) {
    throw Object.assign(new Error('Profile not found'), { status: 404 });
  }
  return profile;
}

module.exports = { createProfile, listProfiles, getProfile };
