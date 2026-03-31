const router = require('express').Router();
const profileController = require('../controllers/profileController');
const gmailController = require('../controllers/gmailController');
const { authenticate } = require('../middleware/auth');

// Profile CRUD
router.post('/', authenticate, profileController.create);
router.get('/', authenticate, profileController.list);
router.get('/:id', authenticate, profileController.getOne);

// Gmail per profile — mounted here so :id is already in scope
router.get('/:id/gmail/connect',   authenticate, gmailController.connect);
router.get('/:id/gmail/messages',  authenticate, gmailController.messages);
router.delete('/:id/gmail',        authenticate, gmailController.disconnect);

module.exports = router;
