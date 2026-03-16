import 'dart:io';

Future<void> main(List<String> args) async {
  final repoRoot = Directory.fromUri(
    Platform.script.resolve('../../'),
  ).path;
  final process = await Process.start(
    'node',
    ['autoresearch/scripts/train.js', ...args],
    workingDirectory: repoRoot,
    runInShell: true,
  );

  await stdout.addStream(process.stdout);
  await stderr.addStream(process.stderr);

  final code = await process.exitCode;
  if (code != 0) {
    exit(code);
  }
}
