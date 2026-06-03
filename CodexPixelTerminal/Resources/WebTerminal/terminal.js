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
    writeFilteredTerminalOutput(base64ToBytes(base64));
  };

  window.codexTerminalFocus = () => {
    terminal.focus();
  };

  window.codexTerminalFit = () => {
    fitAndReport();
  };

  window.codexTerminalReset = () => {
    clearTimeout(pendingTerminalFlushTimer);
    pendingTerminalOutput = new Uint8Array(0);
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

  const hiddenExamplePhrases = [
    'Explain this codebase',
    'Summarize recent commits',
    'Implement {feature}',
    'Find and fix a bug in @filename',
    'Write tests for @filename',
    'Improve documentation in @filename',
    'Run /review on my current changes',
    'Use /skills to list available skills'
  ].map((phrase) => asciiBytes(phrase));
  const outputFilterTailLength = Math.max(
    0,
    ...hiddenExamplePhrases.map((phrase) => phrase.length - 1)
  );
  let pendingTerminalOutput = new Uint8Array(0);
  let pendingTerminalFlushTimer = 0;

  function writeFilteredTerminalOutput(bytes) {
    clearTimeout(pendingTerminalFlushTimer);
    const filtered = removeHiddenExamplePhrases(concatBytes(pendingTerminalOutput, bytes));
    const stableLength = Math.max(0, filtered.length - outputFilterTailLength);

    if (stableLength > 0) {
      terminal.write(filtered.slice(0, stableLength));
    }

    pendingTerminalOutput = filtered.slice(stableLength);
    pendingTerminalFlushTimer = setTimeout(flushPendingTerminalOutput, 80);
  }

  function flushPendingTerminalOutput() {
    if (pendingTerminalOutput.length === 0) {
      return;
    }

    const filtered = removeHiddenExamplePhrases(pendingTerminalOutput);
    pendingTerminalOutput = new Uint8Array(0);
    if (filtered.length > 0) {
      terminal.write(filtered);
    }
  }

  function removeHiddenExamplePhrases(bytes) {
    let result = bytes;
    for (const phrase of hiddenExamplePhrases) {
      result = removeByteSequence(result, phrase);
    }
    return result;
  }

  function removeByteSequence(bytes, target) {
    if (target.length === 0 || bytes.length < target.length) {
      return bytes;
    }

    const output = [];
    for (let index = 0; index < bytes.length;) {
      if (startsWithBytes(bytes, target, index)) {
        index += target.length;
      } else {
        output.push(bytes[index]);
        index += 1;
      }
    }
    return Uint8Array.from(output);
  }

  function startsWithBytes(bytes, target, offset) {
    if (offset + target.length > bytes.length) {
      return false;
    }

    for (let index = 0; index < target.length; index += 1) {
      if (bytes[offset + index] !== target[index]) {
        return false;
      }
    }
    return true;
  }

  function concatBytes(left, right) {
    if (left.length === 0) {
      return right;
    }
    const output = new Uint8Array(left.length + right.length);
    output.set(left, 0);
    output.set(right, left.length);
    return output;
  }

  function asciiBytes(text) {
    const bytes = new Uint8Array(text.length);
    for (let index = 0; index < text.length; index += 1) {
      bytes[index] = text.charCodeAt(index);
    }
    return bytes;
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
