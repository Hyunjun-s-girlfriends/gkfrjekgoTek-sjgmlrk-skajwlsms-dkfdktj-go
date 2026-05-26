/**
 * StudyPulse 서버 진입점
 * LocalServerManager가 `node src/server.js`로 이 파일을 실행합니다.
 */
const path = require('path');
process.chdir(path.join(__dirname, '../server'));
require('../server/src/app');
