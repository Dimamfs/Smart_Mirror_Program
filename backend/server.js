require('dotenv').config();
const app = require('./src/app');

const PORT = process.env.PORT || 3000;

// app.listen(PORT, () => {
//   console.log(`Smart Mirror Backend running on port ${PORT}`);
// });

app.listen(PORT, '127.0.0.1', () => {
  console.log(`Smart Mirror Backend running on http://127.0.0.1:${PORT}`);
});