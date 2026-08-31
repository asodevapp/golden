import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Static hints only: parsing never imports or executes a user's test code.
final class ReviewSourceScenario {
  const ReviewSourceScenario(
      this.description, this.fullName, this.scenario, this.goldenFolder);
  final String description;
  final String fullName;
  final String? scenario;
  final String? goldenFolder;
}

final class ReviewTestSource {
  const ReviewTestSource(
      {this.isGolden = false,
      this.scenarios = const [],
      this.hasTaggedTests = false});
  final bool isGolden;
  final bool hasTaggedTests;
  final List<ReviewSourceScenario> scenarios;
}

List<ReviewSourceScenario> readReviewScenarios(String source) =>
    readReviewTestSource(source).scenarios;

ReviewTestSource readReviewTestSource(String source) {
  final parsed = parseString(content: source, throwIfDiagnostics: false);
  if (parsed.errors.isNotEmpty) return const ReviewTestSource();
  final visitor = _ScenarioVisitor();
  parsed.unit.accept(visitor);
  return ReviewTestSource(
      isGolden: visitor.isGolden,
      scenarios: visitor.scenarios,
      hasTaggedTests: visitor.hasTaggedTests);
}

String? _literal(AstNode? node) {
  if (node is StringLiteral) return node.stringValue;
  // New analyzer releases wrap positional arguments; older releases use the
  // expression itself. Never descend into computed/interpolated expressions.
  if (node is Expression) return null;
  final expression = node?.childEntities.whereType<Expression>().singleOrNull;
  return expression is StringLiteral ? expression.stringValue : null;
}

Expression? _named(ArgumentList arguments, String name) {
  for (final argument in arguments.arguments) {
    if (argument.beginToken.lexeme == name &&
        argument.beginToken.next?.lexeme == ':') {
      return argument.childEntities.whereType<Expression>().lastOrNull;
    }
  }
  return null;
}

ArgumentList? _constructorArguments(Expression? expression) =>
    switch (expression) {
      InstanceCreationExpression() => expression.argumentList,
      MethodInvocation() => expression.argumentList,
      _ => null,
    };

bool _hasCustomPath(ArgumentList arguments) {
  final configuration = _named(arguments, 'configuration');
  final configurationArguments = _constructorArguments(configuration);
  return configuration != null &&
      (configurationArguments == null ||
          _named(configurationArguments, 'pathStrategy') != null);
}

bool _goldenTag(AstNode? node) {
  if (_literal(node) == 'golden') return true;
  if (node is ListLiteral) return node.elements.any(_goldenTag);
  if (node is SetOrMapLiteral && !node.isMap) {
    return node.elements.any(_goldenTag);
  }
  // Positional arguments are wrapped in newer analyzer releases.
  if (node is! Expression) {
    return node?.childEntities.whereType<Expression>().any(_goldenTag) ?? false;
  }
  return false;
}

final class _ScenarioVisitor extends RecursiveAstVisitor<void> {
  final scenarios = <ReviewSourceScenario>[];
  var isGolden = false;
  var hasTaggedTests = false;

  @override
  void visitLibraryDirective(LibraryDirective node) {
    for (final annotation in node.metadata) {
      if (annotation.name.toSource().split('.').last == 'Tags' &&
          _goldenTag(annotation.arguments?.arguments.firstOrNull)) {
        isGolden = true;
        hasTaggedTests = true;
      }
    }
    super.visitLibraryDirective(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    const methods = {
      'testDeviceGoldens',
      'testFfGoldens',
      'testFfGoldenScenarios'
    };
    if ({'test', 'testWidgets', 'group'}.contains(node.methodName.name) &&
        _goldenTag(_named(node.argumentList, 'tags'))) {
      hasTaggedTests = true;
      isGolden = true;
    }
    if (methods.contains(node.methodName.name)) {
      isGolden = true;
    }
    if (methods.contains(node.methodName.name) &&
        node.argumentList.arguments.isNotEmpty) {
      final description = _literal(node.argumentList.arguments.first);
      final groups = <String>[];
      var staticGroups = true;
      for (AstNode? parent = node.parent;
          parent != null;
          parent = parent.parent) {
        if (parent is MethodInvocation && parent.methodName.name == 'group') {
          final group = parent.argumentList.arguments.firstOrNull;
          final name = _literal(group);
          if (name == null) {
            staticGroups = false;
            break;
          }
          groups.insert(0, name);
        }
      }
      if (description != null && staticGroups) {
        void add(String title, String? scenario, String? folder) =>
            scenarios.add(ReviewSourceScenario(
                title, [...groups, title].join(' '), scenario, folder));
        switch (node.methodName.name) {
          case 'testDeviceGoldens':
            final names = _LegacyScenarioNames();
            node.argumentList.accept(names);
            // A builder can capture several scenarios; each runs its whole test.
            if (names.names.isEmpty) {
              add(description, null, null);
            }
            for (final name in names.names) {
              add(description, name, 'golden/$name');
            }
          case 'testFfGoldens':
            final scenario = _literal(_named(node.argumentList, 'scenario'));
            // Custom path strategies are deliberately left to run manifests.
            final customPath = _hasCustomPath(node.argumentList);
            add(
                description,
                scenario,
                scenario == null || customPath
                    ? null
                    : 'golden/${_safeName(scenario)}');
          case 'testFfGoldenScenarios':
            final cases = _named(node.argumentList, 'scenarios');
            if (cases is ListLiteral) {
              for (final element in cases.elements) {
                final arguments = element is Expression
                    ? _constructorArguments(element)
                    : null;
                if (arguments == null ||
                    !element
                        .toSource()
                        .replaceFirst(RegExp(r'^(const|new)\s+'), '')
                        .startsWith('GoldenScenario')) {
                  continue;
                }
                final scenario = _literal(_named(arguments, 'name'));
                if (scenario != null) {
                  add(
                      '$description — $scenario',
                      scenario,
                      _hasCustomPath(node.argumentList)
                          ? null
                          : 'golden/${_safeName(scenario)}');
                }
              }
            }
        }
      }
    }
    super.visitMethodInvocation(node);
  }

  // Mirrors ff_golden's default path naming for source hints, never comparison.
  static String _safeName(String name) => name.trim().isEmpty
      ? 'unnamed'
      : name
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
          .replaceAll(RegExp('-+'), '-')
          .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
}

final class _LegacyScenarioNames extends RecursiveAstVisitor<void> {
  final names = <String>{};
  @override
  void visitArgumentList(ArgumentList node) {
    final name = _literal(_named(node, 'scenarioName'));
    if (name != null) names.add(name);
    super.visitArgumentList(node);
  }
}
