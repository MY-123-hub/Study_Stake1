const j = require('/mnt/c/Users/31222/WorkBuddy/20260417173328/StudyStake/out/StudyStake.sol/StudyStake.json');
const fs = require('fs');
fs.writeFileSync('/mnt/c/Users/31222/WorkBuddy/20260417173328/StudyStake/frontend/src/abi.json', JSON.stringify(j.abi, null, 2));
console.log('ABI extracted OK, entries:', j.abi.length);
