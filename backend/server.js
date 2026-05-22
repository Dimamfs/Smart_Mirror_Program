require('dotenv').config();
const app = require('./src/app');
const mirrorSync = require('./src/services/mirrorSync');

const PORT    = process.env.PORT    || 3000;
const WS_PORT = process.env.WS_PORT || 4000;

app.listen(PORT, '127.0.0.1', () => {
  console.log(`Smart Mirror Backend running on http://127.0.0.1:${PORT}`);
});

mirrorSync.start(WS_PORT);