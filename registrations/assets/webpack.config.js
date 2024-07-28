const path = require("path");
const glob = require("glob");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const CssMinimizerPlugin = require("css-minimizer-webpack-plugin");
const CopyWebpackPlugin = require("copy-webpack-plugin");

module.exports = (env, options) => {
  const devMode = options.mode !== "production";

  return {
    cache: {
      type: "filesystem",
    },
    optimization: {
      minimizer: ["...", new CssMinimizerPlugin()],
    },
    entry: {
      "clandestine-rendezvous": glob
        .sync("./vendor/clandestine-rendezvous/**/*.js")
        .concat(["./js/clandestine-rendezvous.js"]),
      "clandestine-rendezvous-email": glob
        .sync("./vendor/clandestine-rendezvous/**/*.js")
        .concat(["./js/clandestine-rendezvous-email.js"]),
      "unmnemonic-devices": glob
        .sync("./vendor/unmnemonic-devices/**/*.js")
        .concat(["./js/unmnemonic-devices.js"]),
      "unmnemonic-devices-email": glob
        .sync("./vendor/unmnemonic-devices/**/*.js")
        .concat(["./js/unmnemonic-devices-email.js"]),
      waydowntown: glob
        .sync("./vendor/waydowntown/**/*.js")
        .concat(["./js/waydowntown.js"]),
      "waydowntown-email": glob
        .sync("./vendor/waydowntown/**/*.js")
        .concat(["./js/waydowntown-email.js"]),
    },
    externals: ["foundation-sites"],
    output: {
      filename: "[name].js",
      path: path.resolve(__dirname, "../priv/static/js"),
      publicPath: "/js/",
    },
    devtool: devMode ? "eval-cheap-module-source-map" : undefined,
    module: {
      rules: [
        {
          test: /\.(woff|woff2|eot|ttf|svg)$/,
          type: "asset/resource",
        },
        {
          test: /\.js$/,
          exclude: /node_modules/,
          use: {
            loader: "babel-loader",
          },
        },
        {
          test: /\.[s]?css$/,
          use: [
            MiniCssExtractPlugin.loader,
            "css-loader",
            {
              loader: "string-replace-loader",
              options: {
                search: '@charset "UTF-8";',
                replace: "",
                flags: "g",
              },
            },
            {
              loader: "sass-loader",
              options: {
                sassOptions: {
                  includePaths: [path.resolve(__dirname, "node_modules")],
                  outputStyle: "expanded",
                },
              },
            },
          ],
        },
      ],
    },
    plugins: [
      new MiniCssExtractPlugin({ filename: "../css/[name].css" }),
      new CopyWebpackPlugin({ patterns: [{ from: "static/", to: "../" }] }),
    ],
  };
};
