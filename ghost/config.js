var config,
    url = require('url'),
    path = require('path');

function getDatabase() {
  var db_config = {};
  if (process.env['DB_CLIENT']) {
    db_config['client'] = process.env['DB_CLIENT'];
  } else {
    return {
      client: 'sqlite3',
      connection: {
	filename: path.join(__dirname, '/content/data/ghost.db')
      },
      debug: false
    };
  }
  var db_uri = /^tcp:\/\/([\d.]+):(\d+)$/.exec(process.env['DB_PORT']);
  if (db_uri) {
    db_config['connection'] = {
      host: db_uri[1],
      port: db_uri[2]
    };
  } else {
    db_config['connection'] = {
      host: process.env['DB_HOST'] || 'localhost',
      port: process.env['DB_PORT'] || '3305'
    };
  }
  if (process.env['DB_USER']) db_config['connection']['user'] = process.env['DB_USER'];
  if (process.env['DB_PASSWORD']) db_config['connection']['password'] = process.env['DB_PASSWORD'];
  if (process.env['DB_DATABASE']) db_config['connection']['database'] = process.env['DB_DATABASE'];
  return db_config;
}

function getMailConfig() {
  var mail_config = {}
  if (process.env.MAIL_HOST)    { mail_config['host']      = process.env.MAIL_HOST }
  if (process.env.MAIL_SERVICE) { mail_config['service']   = process.env.MAIL_SERVICE }
  if (process.env.MAIL_USER) { mail_config['auth']['user'] = process.env.MAIL_USER }
  if (process.env.MAIL_PASS) { mail_config['auth']['pass'] = process.env.MAIL_PASS }
  return mail_config;
}
if (!process.env.URL) {
  console.log("Please set URL environment variable to your blog's URL");
  process.exit(1);
}

config = {
  production: {
    url: process.env.URL,
    database: getDatabase(),
    mail: getMailConfig(),
    server: {
      host: '0.0.0.0',
      port: '2368'
    }
  },
  development: {
    url: process.env.URL,
    database: getDatabase(),
    mail: getMailConfig(),
    server: {
      host: '0.0.0.0',
      port: '2368'
    }
  },
};
module.exports = config;