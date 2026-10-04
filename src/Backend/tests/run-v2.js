process.env.NODE_ENV = 'test';
process.env.TZ = 'Asia/Ho_Chi_Minh';

const { run } = require('node:test');
const { spec } = require('node:test/reporters');
const fs = require('fs');
const path = require('path');

const testDir = path.join(__dirname, 'v2');

function getTestFiles(dir) {
  let results = [];
  if (!fs.existsSync(dir)) return results;
  const list = fs.readdirSync(dir);
  list.forEach((file) => {
    const fullPath = path.join(dir, file);
    const stat = fs.statSync(fullPath);
    if (stat && stat.isDirectory()) {
      results = results.concat(getTestFiles(fullPath));
    } else if (file.endsWith('.test.js')) {
      results.push(fullPath);
    }
  });
  return results;
}

const files = getTestFiles(testDir);
if (files.length === 0) {
  console.log('No v2 test files found in tests/v2');
  process.exit(0);
}

console.log(`[Backend Test Suite v2] Running ${files.length} test files...`);

run({ files })
  .on('test:fail', () => {
    process.exitCode = 1;
  })
  .compose(new spec())
  .pipe(process.stdout);
