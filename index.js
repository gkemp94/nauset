const express = require('express');
const bodyParser = require('body-parser');

const app = express();

app.use(bodyParser.json({ limit: '50mb' } ));

app.post('*', (req, res) => {
  const body = req.body;
  console.log(body);
  console.log(body.userAgent);
  res.send(200);
});

app.listen(5000);