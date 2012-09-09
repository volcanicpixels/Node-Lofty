#!/usr/bin/env node

/**
 * Module dependencies.
 */

var program = require('commander');

program
  .version('1.0.0')
  .option('-d, --distribute', 'Build distribution version')
  .parse(process.argv);

if (program.distribute) console.log('Building distribution copy') else console.log('Building development copy');