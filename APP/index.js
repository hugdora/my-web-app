const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('<h1> DEPLOYEMENT AUTOMATION WITH GIT HUB ACTION AND TERRAFORM BY THE BIG TEAM OF ENGINEERS GURU!</h1>');
});

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).send('Something broke!');
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
