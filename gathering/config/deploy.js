/* eslint-env node */
'use strict';

module.exports = function () {
  let ENV = {
    build: {},

    sftp: {
      host: process.env.DEPLOYMENT_HOST,
      remoteDir: process.env.DEPLOYMENT_DIRECTORY,
      remoteUser: process.env.DEPLOYMENT_USER,
      privateKey: process.env.DEPLOYMENT_KEY,
    },
  };

  return ENV;
};
