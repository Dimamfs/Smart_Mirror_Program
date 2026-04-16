const router = require('express').Router();
const profileController = require('../controllers/profileController');
const gmailController = require('../controllers/gmailController');
const spotifyController = require('../controllers/spotifyController');
const { authenticate } = require('../middleware/auth');

// Profile CRUD
router.post('/', authenticate, profileController.create);
router.get('/', authenticate, profileController.list);
router.get('/:id', authenticate, profileController.getOne);

// Delete profile
router.delete('/:id', authenticate, profileController.remove);

// Mirror linking — set which mirror this profile appears on
router.patch('/:id/mirror', authenticate, profileController.setMirror);

// Gmail per profile
router.get('/:id/gmail/connect',   authenticate, gmailController.connect);
router.get('/:id/gmail/messages',  authenticate, gmailController.messages);
router.delete('/:id/gmail',        authenticate, gmailController.disconnect);

// Spotify per profile
router.get('/:id/spotify/connect', authenticate, spotifyController.connect);
router.get('/:id/spotify/status',  authenticate, spotifyController.status);
router.delete('/:id/spotify',      authenticate, spotifyController.disconnect);

module.exports = router;
