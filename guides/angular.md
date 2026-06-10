# Angular 21 Code Style Guide

Modern Angular 21 patterns and best practices. Reference this on demand from your project's `CLAUDE.md` (e.g. "Before writing or reviewing code in this stack, read `~/.claude/guides/angular.md`"). Do not `@import` it — that loads the full guide into every session.

## TypeScript

- Use strict type checking
- Prefer type inference when the type is obvious
- Avoid `any`; use `unknown` when type is uncertain
- Always use braces for `if`/`else`/`for`/`while` — no single-line bodies without braces

## Components

- Always use standalone components (do NOT set `standalone: true` in decorators — it's the default)
- Set `changeDetection: ChangeDetectionStrategy.OnPush` in `@Component` decorator
- Keep components small and focused on a single responsibility
- Prefer inline templates for small components
- Use `input()`, `output()`, and `model()` functions instead of `@Input`/`@Output` decorators — `model()` is the signal-based replacement for banana-in-a-box two-way binding
- Do NOT use `@HostBinding`/`@HostListener` — use the `host` object in `@Component`/`@Directive` instead
- Do NOT use `ngClass` — use `class` bindings instead
- Do NOT use `ngStyle` — use `style` bindings instead
- Use `NgOptimizedImage` for all static images (does not work for inline base64)

## Services

- Design services around a single responsibility
- Use `providedIn: 'root'` for singleton services
- Use the `inject()` function instead of constructor injection

## Change Detection

- Angular 21 apps are **zoneless by default** — new projects no longer include `zone.js`
- Signals drive change detection in zoneless apps; avoid patterns that assume zone-triggered checks (e.g. `setTimeout` expecting a view refresh)
- If migrating an older app, flip `provideZonelessChangeDetection()` and audit for missing signal updates before enabling

## Template Syntax

- Use `@if`, `@for`, `@switch` control flow (not `*ngIf`, `*ngFor`, `*ngSwitch`)
- Keep templates simple — avoid complex logic
- Use the `async` pipe to handle observables
- Do NOT write arrow functions in templates (not supported)
- Do NOT assume globals like `new Date()` are available in templates

```html
@if (loading()) {
  <app-loader></app-loader>
}

@for (item of items(); track item.id) {
  <div>{{ item.name }}</div>
}
```

## Signals

- Use signals for local component state
- Use `computed()` for read-only derived state
- Use `linkedSignal()` for writable state that follows a source but accepts manual overrides (e.g. a selection that resets when the list changes but the user can still pick a different value)
- Expose writable signals externally as `.asReadonly()` when consumers shouldn't mutate them
- Keep state transformations pure and predictable

```typescript
readonly items = signal<Item[]>([]);
readonly loading = signal(false);
readonly itemCount = computed(() => this.items().length);

// Preserves user selection if still valid; resets to first option otherwise.
readonly selected = linkedSignal<Item | undefined>({
  source: this.items,
  computation: (items, previous) =>
    items.find((i) => i.id === previous?.value?.id) ?? items[0],
});
```

## Async Data

Prefer the **Resource API** (currently experimental but the recommended direction) over ad-hoc `subscribe()` blocks for signal-backed async state. Resources are reactive to their params, expose `value`, `status`, `error`, `isLoading`, and a `reload()` method.

```typescript
// Plain HTTP GET backed by HttpClient — use httpResource for this common case.
readonly user = httpResource<User>(() => `/api/users/${this.userId()}`);

// Arbitrary async source.
readonly report = resource({
  params: () => ({ id: this.reportId() }),
  loader: ({ params, abortSignal }) =>
    this.reportsService.load(params.id, { signal: abortSignal }),
});

// Observable-based source.
readonly stream = rxResource({
  params: () => ({ q: this.query() }),
  stream: ({ params }) => this.searchService.search(params.q),
});
```

In templates, branch on `status` rather than juggling booleans:

```html
@switch (user.status()) {
  @case ('loading') { <app-loader /> }
  @case ('error')   { <app-error [error]="user.error()" /> }
  @case ('resolved'){ <app-user [user]="user.value()!" /> }
}
```

## RxJS Patterns

Use RxJS for long-lived streams, complex flow orchestration, or interop with observable APIs. For simple HTTP-backed signal state, prefer `httpResource()` / `rxResource()` (see above).

### Cleanup for Long-lived Observables

Use `takeUntilDestroyed` with `DestroyRef`:

```typescript
readonly #destroyRef = inject(DestroyRef);

ngOnInit(): void {
  this.stream$
    .pipe(takeUntilDestroyed(this.#destroyRef))
    .subscribe();
}
```

### One-off HTTP Side Effects

For fire-and-forget HTTP calls that aren't feeding signal state, use `tap/catchError/finalize` with an empty `subscribe()`:

```typescript
this.service.save(payload)
  .pipe(
    catchError((err) => {
      this.toastService.error(err.message || 'Failed to save');
      return EMPTY;
    }),
    finalize(() => this.saving.set(false)),
  )
  .subscribe();
```

## Forms

Two APIs are available in Angular 21:

- **Reactive Forms** — the mature, stable choice. Use for all forms today.
- **Signal Forms** — new, experimental, signal-native forms API. Evaluate for greenfield complex forms; plan to migrate heavy forms once the API stabilizes.

### Validation Errors (Reactive Forms)

```html
<div class="form-group">
  <label>Field Name</label>
  <input type="text" class="form-control" formControlName="name">
  @if (form.get('name')?.invalid && (form.get('name')?.dirty || form.get('name')?.touched)) {
    @if (form.get('name')?.hasError('required')) {
      <div class="input-hint text-danger">Required.</div>
    }
  }
</div>
```

## Routing

- Implement lazy loading for feature routes
- Use functional guards (not class-based `CanActivate`)

```typescript
export const MY_ROUTES: Routes = [
  {
    path: 'my-feature',
    canActivate: [authGuard],
    loadComponent: () => import('./my.component').then((m) => m.MyComponent),
  },
];
```

## SCSS

| Rule | Example |
|------|---------|
| Use CSS variables | `color: var(--text-color)` |
| Use rem/em units | `padding: 1rem` |
| Do NOT use `::ng-deep` | Deprecated — use component styles, CSS variables, or global utility classes |
| Do NOT use `ViewEncapsulation.None` | Keep default encapsulation |
| Do NOT use BEM naming | Use flat, descriptive class names |

```scss
.my-component {
  padding: 1rem;
  border: 1px solid var(--border-color);

  .title {
    margin-bottom: 0.5rem;
    color: var(--text-color);
  }
}
```

## Accessibility

- Must pass all AXE checks
- Must follow WCAG AA minimums: focus management, color contrast, ARIA attributes
- Prefer Angular's built-in ARIA directives (shipped in v21) over hand-rolling `aria-*` bindings where equivalents exist

## Testing

- New projects use **Vitest** as the default test runner (Karma was removed from new app scaffolds in v21)
- Existing Karma projects keep working; migrate via `ng generate @angular/core:karma-to-vitest` when convenient
- Test signal-driven components by reading signals directly (`component.count()`) — no `fakeAsync`/`tick` needed for synchronous signal propagation in zoneless mode
