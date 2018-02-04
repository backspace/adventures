/* eslint-env node */
'use strict';

module.exports = function() {
  let ENV = {
    build: {},

    s3: {
      accessKeyId: process.env.AWS_KEY,
      secretAccessKey: process.env.AWS_SECRET,
      bucket: process.env.AWS_BUCKET,
      region: process.env.AWS_REGION,
    }
  };

  ENV['s3-index'] = Object.assign({}, ENV.s3);

  return ENV;
};
