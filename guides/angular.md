# Angular 19 Code Style Guide

Modern Angular 19 patterns and best practices. Import this into your project's `CLAUDE.md` with `@guides/angular.md`, then add project-specific sections below.

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
- Use `input()` and `output()` functions instead of `@Input`/`@Output` decorators
- Do NOT use `@HostBinding`/`@HostListener` — use the `host` object in `@Component`/`@Directive` instead
- Do NOT use `ngClass` — use `class` bindings instead
- Do NOT use `ngStyle` — use `style` bindings instead
- Use `NgOptimizedImage` for all static images (does not work for inline base64)
- Prefer Reactive forms over Template-driven forms

## Services

- Design services around a single responsibility
- Use `providedIn: 'root'` for singleton services
- Use the `inject()` function instead of constructor injection

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
- Use `computed()` for derived state
- Keep state transformations pure and predictable
- Do NOT use `mutate` on signals — use `update` or `set` instead

```typescript
readonly items = signal<Item[]>([]);
readonly loading = signal(false);
readonly itemCount = computed(() => this.items().length);

loadItems(): void {
  this.loading.set(true);
  this.service.getItems()
    .pipe(
      tap((result) => this.items.set(result)),
      finalize(() => this.loading.set(false)),
    )
    .subscribe();
}
```

## RxJS Patterns

### HTTP Calls

Use `tap/catchError/finalize` with empty `subscribe()`:

```typescript
this.service.load()
  .pipe(
    tap((data) => this.data.set(data)),
    catchError((err) => {
      this.toastService.error(err.message || 'Failed to load');
      return EMPTY;
    }),
    finalize(() => this.loading.set(false)),
  )
  .subscribe();
```

### Cleanup for Long-lived Observables

Use `takeUntilDestroyed` with `DestroyRef` (not needed for HTTP calls):

```typescript
readonly #destroyRef = inject(DestroyRef);

ngOnInit(): void {
  this.stream$
    .pipe(takeUntilDestroyed(this.#destroyRef))
    .subscribe();
}
```

## Forms

### Validation Errors

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
