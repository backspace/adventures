/* jshint node: true */

module.exports = function(deployTarget) {
  var ENV = {
    build: {}
  };

  ENV.s3 = {
    accessKeyId: process.env.AWS_KEY,
    secretAccessKey: process.env.AWS_SECRET,
    bucket: process.env.AWS_BUCKET,
    region: process.env.AWS_REGION,
    filePattern: "*"
  };

  return ENV;
};
