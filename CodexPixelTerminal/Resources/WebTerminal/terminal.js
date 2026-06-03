(() => {
  const host = document.getElementById('terminal-host');
  const bridge = window.webkit?.messageHandlers?.terminalBridge;

  const terminal = new Terminal({
    allowProposedApi: true,
    allowTransparency: false,
    cursorBlink: true,
    cursorStyle: 'block',
    drawBoldTextInBrightColors: true,
    fontFamily: 'Menlo, Monaco, "SF Mono", "Hiragino Sans", monospace',
    fontSize: 13,
    letterSpacing: 0,
    lineHeight: 1.1,
    macOptionIsMeta: true,
    rightClickSelectsWord: true,
    scrollback: 10000,
    tabStopWidth: 8,
    theme: {
      background: '#0a0a0a',
      foreground: '#e0e0e0',
      cursor: '#30d158',
      selectionBackground: '#30d15855',
      black: '#1c1c1c',
      red: '#ff453a',
      green: '#30d158',
      yellow: '#ffd60a',
      blue: '#0a84ff',
      magenta: '#bf5af2',
      cyan: '#64d2ff',
      white: '#f2f2f7',
      brightBlack: '#6c6c70',
      brightRed: '#ff6961',
      brightGreen: '#32d74b',
      brightYellow: '#ffdf5d',
      brightBlue: '#409cff',
      brightMagenta: '#da8fff',
      brightCyan: '#70d7ff',
      brightWhite: '#ffffff'
    }
  });

  const fitAddon = new FitAddon.FitAddon();
  terminal.loadAddon(fitAddon);
  terminal.loadAddon(new WebLinksAddon.WebLinksAddon((_event, uri) => {
    post({ type: 'openLink', url: uri });
  }));

  terminal.open(host);
  installNativeImeAnchoring();

  terminal.onData((data) => {
    post({ type: 'data', data });
  });

  terminal.onBinary((data) => {
    post({ type: 'binary', data: bytesToBase64(data) });
  });

  terminal.onResize(({ cols, rows }) => {
    post({ type: 'resize', cols, rows });
  });

  terminal.onTitleChange((title) => {
    post({ type: 'title', title });
  });

  const resizeObserver = new ResizeObserver(() => {
    debounceFit();
  });
  resizeObserver.observe(host);

  window.codexTerminalWrite = (base64) => {
    terminal.write(base64ToBytes(base64));
  };

  window.codexTerminalFocus = () => {
    terminal.focus();
  };

  window.codexTerminalFit = () => {
    fitAndReport();
  };

  window.codexTerminalReset = () => {
    terminal.reset();
    terminal.clear();
  };

  window.addEventListener('focus', () => {
    terminal.focus();
  });

  document.addEventListener('mousedown', () => {
    terminal.focus();
  });

  requestAnimationFrame(() => {
    fitAndReport();
    terminal.focus();
    post({ type: 'ready', cols: terminal.cols, rows: terminal.rows });
  });

  function post(message) {
    bridge?.postMessage(message);
  }

  function installNativeImeAnchoring() {
    const textarea = terminal.textarea;
    if (!textarea) {
      return;
    }

    textarea.spellcheck = false;
    textarea.autocomplete = 'off';
    textarea.autocorrect = 'off';
    textarea.autocapitalize = 'off';

    textarea.addEventListener('compositionstart', () => {
      document.documentElement.classList.add('ime-composing');
    });

    textarea.addEventListener('compositionend', () => {
      requestAnimationFrame(() => {
        document.documentElement.classList.remove('ime-composing');
      });
    });
  }

  let fitTimer = 0;
  function debounceFit() {
    clearTimeout(fitTimer);
    fitTimer = setTimeout(fitAndReport, 60);
  }

  function fitAndReport() {
    fitAddon.fit();
    post({ type: 'resize', cols: terminal.cols, rows: terminal.rows });
  }

  function base64ToBytes(base64) {
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) {
      bytes[index] = binary.charCodeAt(index);
    }
    return bytes;
  }

  function bytesToBase64(binaryString) {
    let binary = '';
    for (let index = 0; index < binaryString.length; index += 1) {
      binary += String.fromCharCode(binaryString.charCodeAt(index) & 0xff);
    }
    return btoa(binary);
  }
})();
