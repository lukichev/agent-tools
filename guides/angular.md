# Angular 21 Code Style Guide

## TypeScript

- Strict type checking
- Type inference when the type is obvious
- No `any`. Use `unknown` when the type is uncertain
- Braces on every `if`/`else`/`for`/`while` body

## Components

- Standalone components. Do not set `standalone: true`, it is the default
- `changeDetection: ChangeDetectionStrategy.OnPush` in every `@Component`
- Small components with a single responsibility
- Inline templates for small components
- `input()`, `output()` and `model()` instead of `@Input`/`@Output`. `model()` replaces banana-in-a-box two-way binding
- The `host` object in `@Component`/`@Directive` instead of `@HostBinding`/`@HostListener`
- `class` bindings instead of `ngClass`, `style` bindings instead of `ngStyle`
- `NgOptimizedImage` for all static images (not for inline base64)

## Services

- Single responsibility per service
- `providedIn: 'root'` for singletons
- `inject()` instead of constructor injection

## Change Detection

- Angular 21 apps are **zoneless by default**. New projects do not include `zone.js`
- Signals drive change detection. Do not rely on zone-triggered checks, such as a `setTimeout` that expects a view refresh
- When migrating an older app, enable `provideZonelessChangeDetection()` and audit for missing signal updates first

## Template Syntax

- `@if`, `@for`, `@switch`, not `*ngIf`, `*ngFor`, `*ngSwitch`
- No complex logic in templates
- The `async` pipe for observables
- No arrow functions in templates (unsupported)
- No globals such as `new Date()` in templates

```html
@if (loading()) {
  <app-loader></app-loader>
}

@for (item of items(); track item.id) {
  <div>{{ item.name }}</div>
}
```

## Signals

- Signals for local component state
- `computed()` for read-only derived state
- `linkedSignal()` for writable state that follows a source but accepts manual overrides, such as a selection that resets when the list changes
- Expose writable signals as `.asReadonly()` when consumers must not mutate them
- Pure state transformations

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

Prefer the **Resource API** (experimental, but the recommended direction) over `subscribe()` blocks for signal-backed async state. A resource reacts to its params and exposes `value`, `status`, `error`, `isLoading` and `reload()`.

```typescript
// Plain HTTP GET backed by HttpClient - use httpResource for this common case.
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

In templates, branch on `status`:

```html
@switch (user.status()) {
  @case ('loading') { <app-loader /> }
  @case ('error')   { <app-error [error]="user.error()" /> }
  @case ('resolved'){ <app-user [user]="user.value()!" /> }
}
```

## RxJS Patterns

RxJS for long-lived streams, complex orchestration, or observable APIs. For HTTP-backed signal state, `httpResource()` / `rxResource()` (see above).

### Cleanup for Long-lived Observables

`takeUntilDestroyed` with `DestroyRef`:

```typescript
readonly #destroyRef = inject(DestroyRef);

ngOnInit(): void {
  this.stream$
    .pipe(takeUntilDestroyed(this.#destroyRef))
    .subscribe();
}
```

### One-off HTTP Side Effects

For a fire-and-forget HTTP call that feeds no signal, `tap/catchError/finalize` with an empty `subscribe()`:

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

- **Reactive Forms**: stable. Use for all forms today.
- **Signal Forms**: experimental. Evaluate for greenfield complex forms, migrate heavy forms once the API stabilizes.

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

- Lazy loading for feature routes
- Functional guards, not class-based `CanActivate`

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
| Do not use `::ng-deep` | Deprecated. Use component styles, CSS variables, or global utility classes |
| Do not use `ViewEncapsulation.None` | Keep default encapsulation |
| Do not use BEM naming | Use flat, descriptive class names |

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

- Pass all AXE checks
- WCAG AA minimums: focus management, color contrast, ARIA attributes
- Angular's built-in ARIA directives (v21) over hand-written `aria-*` bindings

## Testing

- **Vitest** is the default runner. Karma is gone from new scaffolds in v21
- Migrate an existing Karma project with `ng generate @angular/core:karma-to-vitest`
- Read signals directly in tests (`component.count()`). Zoneless signal propagation is synchronous, so no `fakeAsync`/`tick`
