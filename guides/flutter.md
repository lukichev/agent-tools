# Flutter Code Style Guide

## Tooling
* **Formatting:** `dart format`.
* **Fixes:** `dart fix` to fix common errors and match the analysis options.
* **Linting:** the Dart linter with the recommended rule set.

## Project Structure
* Standard Flutter layout, `lib/main.dart` as the entry point.

## Flutter style guide
* **SOLID:** apply SOLID principles.
* **Concise and declarative:** prefer functional and declarative patterns.
* **Composition over inheritance:** compose widgets and logic.
* **Immutability:** prefer immutable data. Widgets, especially `StatelessWidget`, are immutable.
* **State management:** separate ephemeral state from app state. Manage app state with a state management solution.
* **Widgets are for UI:** compose complex UIs from small reusable widgets.
* **Navigation:** use `auto_route` or `go_router`. See [routing](#routing).

## Package Management
* **Find a package:** pick the most stable candidate on pub.dev.
* **Add a dependency:** `flutter pub add <package_name>`.
* **Add a dev dependency:** `flutter pub add dev:<package_name>`.
* **Add an override:** `flutter pub add override:<package_name>:1.0.0`.
* **Remove a dependency:** `dart pub remove <package_name>`.

## Code Quality
* **Structure:** keep UI logic separate from business logic.
* **Naming:** no abbreviations. Use descriptive, consistent names.
* **Conciseness:** as short as stays clear.
* **Simplicity:** no clever or obscure code.
* **Error handling:** handle errors. Never fail silently.
* **Styling:** max 80 characters per line. `PascalCase` for classes, `camelCase` for members, variables, functions and enums, `snake_case` for files.
* **Functions:** one purpose, under 20 lines.
* **Testing:** use the `file`, `process` and `platform` packages so tests can inject in-memory fakes.
* **Logging:** the `logging` package, not `print`.

## Dart Best Practices
* **Effective Dart:** follow https://dart.dev/effective-dart.
* **Class organization:** related classes share one library file. A large library exports smaller private libraries from one top-level library.
* **Library organization:** related libraries share one folder.
* **API documentation:** doc comments on every public class, constructor, method and top-level function.
* **Comments:** explain non-obvious code only. No trailing comments.
* **Async:** `Future`, `async` and `await` for asynchronous operations. `Stream` for sequences of asynchronous events. Handle errors.
* **Null safety:** sound null safety. Avoid `!` unless the value is guaranteed non-null.
* **Pattern matching:** use it where it simplifies the code.
* **Records:** return multiple values with a record when a class is too heavy.
* **Switch:** prefer exhaustive `switch` statements or expressions.
* **Exceptions:** `try-catch` with the matching exception type. Custom exceptions for cases specific to your code.
* **Arrow functions:** for one-line functions.

## Flutter Best Practices
* **Composition:** compose small widgets instead of extending existing ones. Avoid deep nesting.
* **Private widgets:** small private `Widget` classes, not private helper methods that return a `Widget`.
* **Build methods:** split a large `build()` into private widget classes.
* **Lists:** `ListView.builder` or `SliverList` for long lists.
* **Isolates:** `compute()` for expensive work such as JSON parsing.
* **Const constructors:** use `const` for widgets and inside `build()` wherever possible.
* **Build performance:** no network calls or heavy computation inside `build()`.

## API Design Principles
* Design a reusable API from the user's perspective. It must be easy to use correctly.
* Documentation is part of the API: clear, concise, with examples.

## Application Architecture
* **Separation of concerns:** MVC or MVVM roles: Model, View, ViewModel or Controller.
* **Layers:**
    * Presentation (widgets, screens)
    * Domain (business logic classes)
    * Data (model classes, API clients)
    * Core (shared classes, utilities, and extension types)
* **Feature-based organization:** in a large project, each feature owns its presentation, domain and data subfolders.

## Lint Rules

Start `analysis_options.yaml` from this file:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    # Add additional lint rules here:
    # avoid_print: false
    # prefer_single_quotes: true
```

### State Management
* **Built-in first:** no third-party state package unless the user asks for one.
* **Streams:** `Stream` and `StreamBuilder` for a sequence of asynchronous events.
* **Futures:** `Future` and `FutureBuilder` for a single asynchronous operation.
* **ValueNotifier:** `ValueNotifier` with `ValueListenableBuilder` for simple local state holding one value.

  ```dart
  // Define a ValueNotifier to hold the state.
  final ValueNotifier<int> _counter = ValueNotifier<int>(0);

  // Use ValueListenableBuilder to listen and rebuild.
  ValueListenableBuilder<int>(
    valueListenable: _counter,
    builder: (context, value, child) {
      return Text('Count: $value');
    },
  );
    ```

* **ChangeNotifier:** for complex state or state shared across widgets.
* **ListenableBuilder:** to listen to a `ChangeNotifier` or other `Listenable`.
* **MVVM:** when a more structured solution is needed.
* **Dependency injection:** manual constructor injection, so dependencies are explicit in the API.
* **Provider:** only when the user asks for injection beyond constructors. It exposes services, repositories and state objects to the UI layer.

### Data Flow
* **Data structures:** classes for the data the app uses.
* **Data abstraction:** repositories or services in front of API calls and database operations, for testability.

### Routing
* **GoRouter:** `go_router` for declarative navigation, deep linking and web support.
* **Setup:** add the dependency, then configure the router.

  ```dart
  // 1. Add the dependency
  // flutter pub add go_router

  // 2. Configure the router
  final GoRouter _router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'details/:id', // Route with a path parameter
            builder: (context, state) {
              final String id = state.pathParameters['id']!;
              return DetailScreen(id: id);
            },
          ),
        ],
      ),
    ],
  );

  // 3. Use it in your MaterialApp
  MaterialApp.router(
    routerConfig: _router,
  );
  ```
* **Authentication redirects:** use the `redirect` property. Send an unauthorized user to login, then back to the intended route.

* **Navigator:** the built-in `Navigator` for short-lived screens that need no deep link, such as dialogs.

  ```dart
  // Push a new screen onto the stack
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const DetailsScreen()),
  );

  // Pop the current screen to go back
  Navigator.pop(context);
  ```

### Data Handling & Serialization
* **JSON:** `json_serializable` and `json_annotation`.
* **Field renaming:** `fieldRename: FieldRename.snake` maps camelCase fields to snake_case keys.

  ```dart
  // In your model file
  import 'package:json_annotation/json_annotation.dart';

  part 'user.g.dart';

  @JsonSerializable(fieldRename: FieldRename.snake)
  class User {
    final String firstName;
    final String lastName;

    User({required this.firstName, required this.lastName});

    factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
    Map<String, dynamic> toJson() => _$UserToJson(this);
  }
  ```


### Logging
* **Structured logging:** `log` from `dart:developer`, which integrates with Dart DevTools.

  ```dart
  import 'dart:developer' as developer;

  // For simple messages
  developer.log('User logged in successfully.');

  // For structured error logging
  try {
    // ... code that might fail
  } catch (e, s) {
    developer.log(
      'Failed to fetch data',
      name: 'myapp.network',
      level: 1000, // SEVERE
      error: e,
      stackTrace: s,
    );
  }
  ```

## Code Generation
* `build_runner` is a dev dependency in `pubspec.yaml` and runs all code generation, including `json_serializable`.
* After editing a file that needs generation:

  ```shell
  dart run build_runner build --delete-conflicting-outputs
  ```

## Testing
* **Run:** `flutter test`.
* **Unit tests:** `package:test`, for domain logic, the data layer and state management.
* **Widget tests:** `package:flutter_test`, for UI components.
* **Integration tests:** `package:integration_test` from the Flutter SDK, for end-to-end flows. Add it as a `dev_dependency` with `sdk: flutter`.
* **Assertions:** `package:checks` over the default `matchers`.
* **Convention:** Arrange-Act-Assert.
* **Mocks:** prefer fakes or stubs. When a mock is required, use `mockito` or `mocktail` without code generation.
* **Coverage:** aim high.

## Visual Design & Theming
* **UI:** follow modern design guidelines.
* **Responsiveness:** adapt to every screen size, mobile and web. Use `LayoutBuilder` or `MediaQuery`.
* **Navigation:** an app with several pages has a clear navigation bar or controls.
* **Typography:** differentiate hero text, section headlines, list headlines and keywords by size.
* **Background:** a subtle noise texture on the main background.
* **Shadows:** multi-layered drop shadows. Cards have a soft, deep shadow.
* **Icons:** use icons to support understanding and navigation.
* **Interactive elements:** buttons, checkboxes, sliders, lists and charts carry a shadow with a colored glow.
* **Text:** `Theme.of(context).textTheme` for text styles.
* **Text fields:** set `textCapitalization`, `keyboardType` and `placeholder`.

### Theming
* **Centralized theme:** one `ThemeData` for the whole app.
* **Light and dark:** pass both `theme` and `darkTheme` to `MaterialApp`. Control `themeMode` (`ThemeMode.light`, `ThemeMode.dark`, `ThemeMode.system`) from state, for example a `ChangeNotifierProvider`, for a user toggle.
* **Color scheme:** `ColorScheme.fromSeed` builds the light and dark palettes from one seed color.

  ```dart
  final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    ),
    // ... other theme properties
  );
  ```
* **Palette:** a wide range of hues and concentrations.
* **Component themes:** `appBarTheme`, `elevatedButtonTheme`, `cardTheme` and similar properties inside `ThemeData`, never per widget.
* **Custom fonts:** the `google_fonts` package, applied through a `TextTheme`.

  ```dart
  // 1. Add the dependency
  // flutter pub add google_fonts

  // 2. Define a TextTheme with a custom font
  final TextTheme appTextTheme = TextTheme(
    displayLarge: GoogleFonts.oswald(fontSize: 57, fontWeight: FontWeight.bold),
    titleLarge: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w500),
    bodyMedium: GoogleFonts.openSans(fontSize: 14),
  );
  ```

```dart
// main.dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 57.0, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(fontSize: 14.0, height: 1.4),
    ),
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ),
  ),
  home: const MyHomePage(),
);
```

### Assets and Images
* **Images:** relevant, correctly sized and licensed. Use placeholders when real images are absent.
* **Asset declaration:** every asset path in `pubspec.yaml`.

    ```yaml
    flutter:
      uses-material-design: true
      assets:
        - assets/images/
    ```

* **Local images:** `Image.asset`.

    ```dart
    Image.asset('assets/images/placeholder.png')
    ```
* **Network images:** `Image.network` with `loadingBuilder` and `errorBuilder`. Use `NetworkImage` where an `ImageProvider` is required, and `cached_network_image` for caching.
* **Custom icons:** `ImageIcon` for an icon from an `ImageProvider`.

  ```dart
  // When using network images, always provide an errorBuilder.
  Image.network(
    'https://picsum.photos/200/300',
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return const Center(child: CircularProgressIndicator());
    },
    errorBuilder: (context, error, stackTrace) {
      return const Icon(Icons.error);
    },
  )
  ```

### Design Tokens with `ThemeExtension`

For styles outside the standard `ThemeData`:

* Define a class that extends `ThemeExtension<T>` with the custom properties.
* Implement `copyWith` and `lerp`. Theme transitions require both.
* Add the extension to the `extensions` list in `ThemeData`.
* Read tokens with `Theme.of(context).extension<MyColors>()!`.

```dart
// 1. Define the extension
@immutable
class MyColors extends ThemeExtension<MyColors> {
  const MyColors({required this.success, required this.danger});

  final Color? success;
  final Color? danger;

  @override
  ThemeExtension<MyColors> copyWith({Color? success, Color? danger}) {
    return MyColors(success: success ?? this.success, danger: danger ?? this.danger);
  }

  @override
  ThemeExtension<MyColors> lerp(ThemeExtension<MyColors>? other, double t) {
    if (other is! MyColors) return this;
    return MyColors(
      success: Color.lerp(success, other.success, t),
      danger: Color.lerp(danger, other.danger, t),
    );
  }
}

// 2. Register it in ThemeData
theme: ThemeData(
  extensions: const <ThemeExtension<dynamic>>[
    MyColors(success: Colors.green, danger: Colors.red),
  ],
),

// 3. Use it in a widget
Container(
  color: Theme.of(context).extension<MyColors>()!.success,
)
```

### Styling with `WidgetStateProperty`

* **`WidgetStateProperty.resolveWith`:** a function from `Set<WidgetState>` to the value for that state.
* **`WidgetStateProperty.all`:** one value for every state.

```dart
// Example: Creating a button style that changes color when pressed.
final ButtonStyle myButtonStyle = ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith<Color>(
    (Set<WidgetState> states) {
      if (states.contains(WidgetState.pressed)) {
        return Colors.green; // Color when pressed
      }
      return Colors.red; // Default color
    },
  ),
);
```

## Layout Best Practices

### Rows and Columns

* **`Expanded`:** fill the remaining space on the main axis.
* **`Flexible`:** shrink to fit without growing. Never mix `Flexible` and `Expanded` in one `Row` or `Column`.
* **`Wrap`:** move overflowing children to the next line.

### General Content

* **`SingleChildScrollView`:** fixed-size content larger than the viewport.
* **`ListView` / `GridView`:** always the `.builder` constructor for long content.
* **`FittedBox`:** scale or fit one child inside its parent.
* **`LayoutBuilder`:** layout decisions based on the available space.

### Stack

* **`Positioned`:** anchor a child to the edges of a `Stack`.
* **`Align`:** place a child by alignment, such as `Alignment.center`.

### Overlays

* **`OverlayPortal`:** show UI such as dropdowns or tooltips above everything else. It manages the `OverlayEntry`.

  ```dart
  class MyDropdown extends StatefulWidget {
    const MyDropdown({super.key});

    @override
    State<MyDropdown> createState() => _MyDropdownState();
  }

  class _MyDropdownState extends State<MyDropdown> {
    final _controller = OverlayPortalController();

    @override
    Widget build(BuildContext context) {
      return OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (BuildContext context) {
          return const Positioned(
            top: 50,
            left: 10,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('I am an overlay!'),
              ),
            ),
          );
        },
        child: ElevatedButton(
          onPressed: _controller.toggle,
          child: const Text('Toggle Overlay'),
        ),
      );
    }
  }
  ```

## Color Scheme Best Practices

### Contrast Ratios

* **WCAG 2.1.**
* **Normal text:** at least **4.5:1**.
* **Large text** (18pt, or 14pt bold): at least **3:1**.

### Palette Selection

* **Hierarchy:** primary, secondary and accent.
* **60-30-10:** 60% primary or neutral, 30% secondary, 10% accent.

### Complementary Colors

* Accent colors only. Jarring when overused, and hard on the eyes as text on background.

### Example Palette

* **Primary:** #0D47A1 (Dark Blue)
* **Secondary:** #1976D2 (Medium Blue)
* **Accent:** #FFC107 (Amber)
* **Neutral/Text:** #212121 (Almost Black)
* **Background:** #FEFEFE (Almost White)

## Font Best Practices

### Font Selection

* **Families:** one or two for the whole app.
* **Legibility:** sans-serif for UI body text.
* **System fonts:** consider platform-native fonts.
* **Google Fonts:** the `google_fonts` package.

### Hierarchy and Scale

* **Scale:** a fixed set of sizes for headlines, titles, body and captions.
* **Weight:** differentiate text by weight.
* **Color and opacity:** de-emphasize secondary text.

### Readability

* **Line height:** **1.4x to 1.6x** the font size.
* **Line length:** **45-75 characters** for body text.
* **All caps:** never for long-form text.

### Example Typographic Scale

```dart
// In your ThemeData
textTheme: const TextTheme(
  displayLarge: TextStyle(fontSize: 57.0, fontWeight: FontWeight.bold),
  titleLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
  bodyLarge: TextStyle(fontSize: 16.0, height: 1.5),
  bodyMedium: TextStyle(fontSize: 14.0, height: 1.4),
  labelSmall: TextStyle(fontSize: 11.0, color: Colors.grey),
),
```

## Documentation

* **`dartdoc`:** `///` comments on every public API. Document private APIs too where useful.
* **Why, not what:** comments explain why the code is written this way.
* **For the reader:** answer the question where a reader first looks for it.
* **No restatement:** a comment that repeats the name or signature is removed.
* **Consistent terms.**
* **Summary first:** one sentence ending in a period, then a blank line, then the detail.
* **Getter and setter:** document one, the tool merges them.
* **Library comments:** a library-level doc comment gives the overview.
* **Code samples:** add them where they show usage.
* **Parameters, return values, exceptions:** describe them in prose.
* **Position:** doc comments come before annotations.
* **Style:** brief, no jargon or unexplained abbreviations, minimal Markdown, no HTML. Code in fenced blocks with a language.

## Accessibility (A11Y)
* **Color contrast:** at least **4.5:1** for text.
* **Dynamic text scaling:** the UI stays usable at larger system font sizes.
* **Semantic labels:** the `Semantics` widget on UI elements.
* **Screen readers:** test with TalkBack (Android) and VoiceOver (iOS).
