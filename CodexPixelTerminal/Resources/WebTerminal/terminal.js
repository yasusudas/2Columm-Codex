(() => {
  const host = document.getElementById('terminal-host');
  const bridge = window.webkit?.messageHandlers?.terminalBridge;

  const terminal = new Terminal({
    allowProposedApi: true,
    allowTransparency: false,
    cursorBlink: true,
    cursorInactiveStyle: 'bar',
    cursorStyle: 'bar',
    cursorWidth: 2,
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
      cursor: '#ffffff',
      cursorAccent: '#0a0a0a',
      selectionBackground: '#ffffff33',
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
    const compositionView = host.querySelector('.composition-view');
    if (!textarea || !compositionView) {
      return;
    }

    textarea.spellcheck = false;
    textarea.autocomplete = 'off';
    textarea.autocorrect = 'off';
    textarea.autocapitalize = 'off';

    let isComposing = false;
    let compositionText = '';
    let compositionStartOffset = 0;
    let compositionFrame = 0;

    textarea.addEventListener('compositionstart', () => {
      isComposing = true;
      compositionText = '';
      compositionStartOffset = textarea.selectionStart ?? textarea.value.length;
      document.documentElement.classList.add('ime-composing');
      compositionView.classList.add('codex-ime-overlay');
      scheduleCompositionOverlayUpdate();
    });

    textarea.addEventListener('compositionupdate', (event) => {
      compositionText = event.data ?? '';
      scheduleCompositionOverlayUpdate();
    });

    textarea.addEventListener('compositionend', () => {
      isComposing = false;
      compositionText = '';
      requestAnimationFrame(() => {
        document.documentElement.classList.remove('ime-composing');
        compositionView.classList.remove('codex-ime-overlay');
        compositionView.replaceChildren();
      });
    });

    textarea.addEventListener('input', () => {
      if (isComposing) {
        scheduleCompositionOverlayUpdate();
      }
    });

    textarea.addEventListener('keydown', () => {
      if (isComposing) {
        scheduleCompositionOverlayUpdate();
      }
    });

    textarea.addEventListener('keyup', () => {
      if (isComposing) {
        scheduleCompositionOverlayUpdate();
      }
    });

    document.addEventListener('selectionchange', () => {
      if (isComposing && document.activeElement === textarea) {
        scheduleCompositionOverlayUpdate();
      }
    });

    terminal.onCursorMove(() => {
      if (isComposing) {
        scheduleCompositionOverlayUpdate();
      }
    });

    function scheduleCompositionOverlayUpdate() {
      if (compositionFrame) {
        return;
      }

      compositionFrame = requestAnimationFrame(() => {
        compositionFrame = 0;
        updateCompositionOverlay();
        if (isComposing) {
          scheduleCompositionOverlayUpdate();
        }
      });
    }

    function updateCompositionOverlay() {
      if (!isComposing) {
        return;
      }

      const text = currentCompositionText();
      const selection = currentCompositionSelection(text);
      renderCompositionOverlay(text, selection.start, selection.end);
    }

    function currentCompositionText() {
      if (compositionText.length > 0) {
        return compositionText;
      }

      const pendingText = textarea.value.slice(compositionStartOffset);
      return pendingText.length > 0 ? pendingText : textarea.value;
    }

    function currentCompositionSelection(text) {
      const valueLength = textarea.value.length;
      const hasNativeSelection = valueLength >= compositionStartOffset + text.length;
      if (!hasNativeSelection) {
        return { start: text.length, end: text.length };
      }

      const rawStart = textarea.selectionStart ?? valueLength;
      const rawEnd = textarea.selectionEnd ?? rawStart;
      return {
        start: clamp(rawStart - compositionStartOffset, 0, text.length),
        end: clamp(rawEnd - compositionStartOffset, 0, text.length)
      };
    }

    function renderCompositionOverlay(text, selectionStart, selectionEnd) {
      compositionView.replaceChildren();

      appendSegment(text.slice(0, selectionStart), 'ime-segment');
      appendSegment(text.slice(selectionStart, selectionEnd), 'ime-segment ime-selected-segment');

      const caret = document.createElement('span');
      caret.className = 'ime-caret';
      caret.setAttribute('aria-hidden', 'true');
      compositionView.appendChild(caret);

      appendSegment(text.slice(selectionEnd), 'ime-segment');
    }

    function appendSegment(text, className) {
      if (text.length === 0) {
        return;
      }
      const segment = document.createElement('span');
      segment.className = className;
      segment.textContent = text;
      compositionView.appendChild(segment);
    }

    function clamp(value, min, max) {
      return Math.max(min, Math.min(max, value));
    }
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
