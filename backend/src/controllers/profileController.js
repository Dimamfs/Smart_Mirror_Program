const profileService = require('../services/profileService');

async function create(req, res, next) {
  try {
    const { name, email } = req.body;
    const householdId = req.account.householdId;

    if (!name || !name.trim()) {
      return res.status(400).json({ error: 'Profile name is required' });
    }

    const profile = await profileService.createProfile({ householdId, name: name.trim(), email });
    res.status(201).json({ profile });
  } catch (err) {
    next(err);
  }
}

async function list(req, res, next) {
  try {
    const householdId = req.account.householdId;
    const profiles = await profileService.listProfiles(householdId);
    res.json({ profiles });
  } catch (err) {
    next(err);
  }
}

async function getOne(req, res, next) {
  try {
    const profile = await profileService.getProfile(Number(req.params.id));

    if (profile.household_id !== req.account.householdId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    res.json({ profile });
  } catch (err) {
    next(err);
  }
}

module.exports = { create, list, getOne };
