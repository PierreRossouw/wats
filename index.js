if (window.WebAssembly === void 0) {
  alert("Your browser doesn't support WebAssembly!");
}

var xmlhttp, ogWasm;
xmlhttp = new XMLHttpRequest();
xmlhttp.open('GET', 'compile.dwasm.txt', false);
xmlhttp.send();
compilerSource.value = xmlhttp.responseText;

xmlhttp.open('GET', 'compile.dwasm.bin.txt', false);
xmlhttp.send();
ogWasm = xmlhttp.responseText.trim();
ogWasm = hexStringToByte(ogWasm.replace(/,/g, ""));

xmlhttp.open('GET', 'playtest.dwasm.txt', false);
xmlhttp.send();
testSource.value = xmlhttp.responseText;

function hexStringToByte(str) {
  if (!str) {
    return new Uint8Array();
  }
  var a = [];
  for (var i = 0, len = str.length; i < len; i += 2) {
    a.push(parseInt(str.substr(i, 2), 16));
  }
  return new Uint8Array(a);
};

function byteToHexString(uint8arr) {
  if (!uint8arr) {
    return '';
  }
  var hexStr = '';
  for (var i = 0; i < uint8arr.length; i++) {
    var hex = (uint8arr[i] & 0xff).toString(16);
    hex = (hex.length === 1) ? '0' + hex : hex;
    hexStr += hex + ',';
  }
  return hexStr.slice(0, -1);
}

function byteToDumpString(uint8arr) {
  if (!uint8arr) {
    return '';
  }
  var hexStr = '';
  for (var i = 0; i < uint8arr.length; i++) {
    var hex = (uint8arr[i] & 0xff).toString(16);
    hex = (hex.length === 1) ? '0' + hex : hex;
    hexStr += hex;
    if (i % 4 == 3) {
      hexStr += ' ';
    };
  };
  hexStr = hexStr.replace(/01dec0de/g, '\nDEBUG   ');
  hexStr = hexStr.replace(/02dec0de/g, '\nNode    ');
  hexStr = hexStr.replace(/03dec0de/g, '\nScope   ');
  hexStr = hexStr.replace(/04dec0de/g, '\nList    ');
  hexStr = hexStr.replace(/05dec0de/g, '\nItem    ');
  hexStr = hexStr.replace(/06dec0de/g, '\nToken   ');
  hexStr = hexStr.replace(/07dec0de/g, '\nString  ');
  return hexStr;
}

compilerCompile.onclick = (e) => {
  compilerBinary.value = "";
  WebAssembly.instantiate(ogWasm).then(results => {
    let mem = new Uint8Array(results.instance.exports.memory.buffer);
    let sourcecode = compilerSource.value;
    new Uint32Array(mem.buffer)[2] = sourcecode.length;
    for (var i = 0, strLen = sourcecode.length; i < strLen; i++) { mem[i + 12] = sourcecode.charCodeAt(i); }
    let out = results.instance.exports.main();
    let binLen = mem[out] + (mem[out + 1] << 8) + (mem[out + 2] << 16) + (mem[out + 3] << 24);
    out = out + 4;
    if (0x6d7361 == mem[out + 1] + (mem[out + 2] << 8) + (mem[out + 3] << 16)) {
      let compilerWasm = mem.slice(out, out + binLen)
      compilerBinary.value = byteToHexString(compilerWasm);
      testMemory.value = byteToDumpString(mem.slice(0, 64000));
    } else {
      compilerBinary.value = String.fromCharCode.apply(null, mem.slice(out, out + binLen));
      testMemory.value = byteToDumpString(mem.slice(0, 64000));
    };
  });
};

testCompile.onclick = (e) => {
  testBinary.value = "";
  let compilerWasm = hexStringToByte(compilerBinary.replace(/,/g, ""));
  WebAssembly.instantiate(compilerWasm).then(results => {
    let mem = new Uint8Array(results.instance.exports.memory.buffer);
    let sourcecode = testSource.value;
    new Uint32Array(mem.buffer)[2] = sourcecode.length;
    for (var i = 0, strLen = sourcecode.length; i < strLen; i++) { mem[i + 12] = sourcecode.charCodeAt(i); }
    let out = results.instance.exports.main();
    let outLen = mem[out] + (mem[out + 1] << 8) + (mem[out + 2] << 16) + (mem[out + 3] << 24);
    out = out + 4;
    if (0x6d7361 == mem[out + 1] + (mem[out + 2] << 8) + (mem[out + 3] << 16)) {
      let testWasm = mem.slice(out, out + outLen);
      testBinary.value = byteToHexString(testWasm)
      testMemory.value = byteToDumpString(mem.slice(0, 64000));
    } else {   // Error message
      testBinary.value = String.fromCharCode.apply(null, mem.slice(out, out + outLen));
      testMemory.value = byteToDumpString(mem.slice(0, 64000));
    };
  });
};

execute.onclick = (e) => {
  testMemory.value = "";
  let testWasm = hexStringToByte(testBinary.replace(/,/g, ""));
  WebAssembly.instantiate(testWasm).then(results => {
    if (results.instance.exports.memory) {
      let mem = new Uint8Array(results.instance.exports.memory.buffer);
      execResult.value = results.instance.exports.main();
      testMemory.value = byteToDumpString(mem.slice(0, 64000));
    } else {
      execResult.value = results.instance.exports.main();
    }
  });
};
