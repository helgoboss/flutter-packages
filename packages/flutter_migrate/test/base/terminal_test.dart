// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_migrate/src/base/io.dart';
import 'package:flutter_migrate/src/base/logger.dart';
import 'package:flutter_migrate/src/base/terminal.dart';
import 'package:test/fake.dart';

import '../src/common.dart';

void main() {
  group('output preferences', () {
    testWithoutContext('can wrap output', () async {
      final BufferLogger bufferLogger = BufferLogger(
        outputPreferences:
            OutputPreferences.test(wrapText: true, wrapColumn: 40),
        terminal: TestTerminal(),
      );
      bufferLogger.printStatus('0123456789' * 8);

      expect(bufferLogger.statusText, equals('${'0123456789' * 4}\n' * 2));
    });

    testWithoutContext('can turn off wrapping', () async {
      final BufferLogger bufferLogger = BufferLogger(
        outputPreferences: OutputPreferences.test(),
        terminal: TestTerminal(),
      );
      final String testString = '0123456789' * 20;
      bufferLogger.printStatus(testString);

      expect(bufferLogger.statusText, equals('$testString\n'));
    });
  });

  group('ANSI coloring and bold', () {
    late AnsiTerminal terminal;

    setUp(() {
      terminal = AnsiTerminal(
        stdio: Stdio(), // Danger, using real stdio.
        supportsColor: true,
      );
    });

    testWithoutContext('adding colors works', () {
      for (final TerminalColor color in TerminalColor.values) {
        expect(
          terminal.color('output', color),
          equals(
              '${AnsiTerminal.colorCode(color)}output${AnsiTerminal.resetColor}'),
        );
      }
    });

    testWithoutContext('adding bold works', () {
      expect(
        terminal.bolden('output'),
        equals('${AnsiTerminal.bold}output${AnsiTerminal.resetBold}'),
      );
    });

    testWithoutContext('nesting bold within color works', () {
      expect(
        terminal.color(terminal.bolden('output'), TerminalColor.blue),
        equals(
            '${AnsiTerminal.blue}${AnsiTerminal.bold}output${AnsiTerminal.resetBold}${AnsiTerminal.resetColor}'),
      );
      expect(
        terminal.color('non-bold ${terminal.bolden('output')} also non-bold',
            TerminalColor.blue),
        equals(
            '${AnsiTerminal.blue}non-bold ${AnsiTerminal.bold}output${AnsiTerminal.resetBold} also non-bold${AnsiTerminal.resetColor}'),
      );
    });

    testWithoutContext('nesting color within bold works', () {
      expect(
        terminal.bolden(terminal.color('output', TerminalColor.blue)),
        equals(
            '${AnsiTerminal.bold}${AnsiTerminal.blue}output${AnsiTerminal.resetColor}${AnsiTerminal.resetBold}'),
      );
      expect(
        terminal.bolden(
            'non-color ${terminal.color('output', TerminalColor.blue)} also non-color'),
        equals(
            '${AnsiTerminal.bold}non-color ${AnsiTerminal.blue}output${AnsiTerminal.resetColor} also non-color${AnsiTerminal.resetBold}'),
      );
    });

    testWithoutContext('nesting color within color works', () {
      expect(
        terminal.color(terminal.color('output', TerminalColor.blue),
            TerminalColor.magenta),
        equals(
            '${AnsiTerminal.magenta}${AnsiTerminal.blue}output${AnsiTerminal.resetColor}${AnsiTerminal.magenta}${AnsiTerminal.resetColor}'),
      );
      expect(
        terminal.color(
            'magenta ${terminal.color('output', TerminalColor.blue)} also magenta',
            TerminalColor.magenta),
        equals(
            '${AnsiTerminal.magenta}magenta ${AnsiTerminal.blue}output${AnsiTerminal.resetColor}${AnsiTerminal.magenta} also magenta${AnsiTerminal.resetColor}'),
      );
    });

    testWithoutContext('nesting bold within bold works', () {
      expect(
        terminal.bolden(terminal.bolden('output')),
        equals('${AnsiTerminal.bold}output${AnsiTerminal.resetBold}'),
      );
      expect(
        terminal.bolden('bold ${terminal.bolden('output')} still bold'),
        equals(
            '${AnsiTerminal.bold}bold output still bold${AnsiTerminal.resetBold}'),
      );
    });
  });

  group('character input prompt', () {
    late AnsiTerminal terminalUnderTest;

    setUp(() {
      terminalUnderTest = TestTerminal(stdio: FakeStdio());
    });

    testWithoutContext('character prompt throws if usesTerminalUi is false',
        () async {
      expect(
          terminalUnderTest.promptForCharInput(
            <String>['a', 'b', 'c'],
            prompt: 'Please choose something',
            logger: BufferLogger.test(),
          ),
          throwsStateError);
    });

    testWithoutContext('character prompt', () async {
      final BufferLogger bufferLogger = BufferLogger(
        terminal: terminalUnderTest,
        outputPreferences: OutputPreferences.test(),
      );
      terminalUnderTest.usesTerminalUi = true;
      mockStdInStream = Stream<String>.fromFutures(<Future<String>>[
        Future<String>.value('d'), // Not in accepted list.
        Future<String>.value('\n'), // Not in accepted list
        Future<String>.value('b'),
      ]).asBroadcastStream();
      final String choice = await terminalUnderTest.promptForCharInput(
        <String>['a', 'b', 'c'],
        prompt: 'Please choose something',
        logger: bufferLogger,
      );
      expect(choice, 'b');
      expect(
          bufferLogger.statusText,
          'Please choose something [a|b|c]: d\n'
          'Please choose something [a|b|c]: \n'
          'Please choose something [a|b|c]: b\n');
    });

    testWithoutContext(
        'default character choice without displayAcceptedCharacters', () async {
      final BufferLogger bufferLogger = BufferLogger(
        terminal: terminalUnderTest,
        outputPreferences: OutputPreferences.test(),
      );
      terminalUnderTest.usesTerminalUi = true;
      mockStdInStream = Stream<String>.fromFutures(<Future<String>>[
        Future<String>.value('\n'), // Not in accepted list
      ]).asBroadcastStream();
      final String choice = await terminalUnderTest.promptForCharInput(
        <String>['a', 'b', 'c'],
        prompt: 'Please choose something',
        displayAcceptedCharacters: false,
        defaultChoiceIndex: 1, // which is b.
        logger: bufferLogger,
      );

      expect(choice, 'b');
      expect(bufferLogger.statusText, 'Please choose something: \n');
    });

    testWithoutContext(
        'Does not set single char mode when a terminal is not attached', () {
      final Stdio stdio = FakeStdio()..stdinHasTerminal = false;
      final AnsiTerminal ansiTerminal = AnsiTerminal(
        stdio: stdio,
      );

      expect(() => ansiTerminal.singleCharMode = true, returnsNormally);
    });
  });

  testWithoutContext('AnsiTerminal.preferredStyle', () {
    final Stdio stdio = FakeStdio();
    expect(AnsiTerminal(stdio: stdio).preferredStyle,
        0); // Defaults to 0 for backwards compatibility.

    expect(AnsiTerminal(stdio: stdio, now: DateTime(2018)).preferredStyle, 0);
    expect(AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 2)).preferredStyle,
        1);
    expect(AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 3)).preferredStyle,
        2);
    expect(AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 4)).preferredStyle,
        3);
    expect(AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 5)).preferredStyle,
        4);
    expect(AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 6)).preferredStyle,
        5);
    expect(AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 7)).preferredStyle,
        5);
    expect(AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 8)).preferredStyle,
        0);
    expect(AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 9)).preferredStyle,
        1);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 10)).preferredStyle,
        2);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 11)).preferredStyle,
        3);

    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 1, 1)).preferredStyle,
        0);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 2, 1)).preferredStyle,
        1);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 3, 1)).preferredStyle,
        2);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 4, 1)).preferredStyle,
        3);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 5, 1)).preferredStyle,
        4);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 6, 1)).preferredStyle,
        6);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 7, 1)).preferredStyle,
        6);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 8, 1)).preferredStyle,
        0);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 9, 1)).preferredStyle,
        1);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 10, 1))
            .preferredStyle,
        2);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 11, 1))
            .preferredStyle,
        3);

    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 1, 23))
            .preferredStyle,
        0);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 2, 23))
            .preferredStyle,
        1);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 3, 23))
            .preferredStyle,
        2);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 4, 23))
            .preferredStyle,
        3);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 5, 23))
            .preferredStyle,
        4);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 6, 23))
            .preferredStyle,
        28);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 7, 23))
            .preferredStyle,
        28);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 8, 23))
            .preferredStyle,
        0);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 9, 23))
            .preferredStyle,
        1);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 10, 23))
            .preferredStyle,
        2);
    expect(
        AnsiTerminal(stdio: stdio, now: DateTime(2018, 1, 11, 23))
            .preferredStyle,
        3);
  });
}

late Stream<String> mockStdInStream;

class TestTerminal extends AnsiTerminal {
  TestTerminal({
    Stdio? stdio,
    DateTime? now,
  }) : super(stdio: stdio ?? Stdio(), now: now ?? DateTime(2018));

  @override
  Stream<String> get keystrokes {
    return mockStdInStream;
  }

  @override
  bool singleCharMode = false;

  @override
  int get preferredStyle => 0;
}

class FakeStdio extends Fake implements Stdio {
  @override
  bool stdinHasTerminal = false;
}
