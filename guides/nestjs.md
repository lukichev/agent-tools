# NestJS Style Guide

## 1. Project Structure

Organize by **vertical feature slices**. Each module is self-contained.

```
src/
  _nest/
    feature-name/
      feature-name.module.ts
      feature-name.controller.ts
      feature-name.service.ts
      feature-name.entity.ts
      feature-name.dto.ts
      feature-name.interfaces.ts
      dtos/
        create-feature.dto.ts
        update-feature.dto.ts
        list-feature.dto.ts
      entities/
        feature.repository.ts
      listeners/
        some-event.listener.ts
    _shared/
      dtos/
        pagination.dto.ts
      entities/
        auditable.ts
      pipes/
      guards/
      interceptors/
    _utils/
      typeorm.ts
    _migrations/
      mysql/
      pgsql/
    core.module.ts
    server.module.ts
```

**Rules:**
- One module per feature domain. Never put two unrelated features in one module.
- Shared building blocks go in `_shared/`, not in feature modules.
- Utilities (pure functions, helpers) go in `_utils/`.
- Never auto-generate a migration in production. Review before you run one.

## 2. Naming Conventions

| Artifact         | Convention          | Example                          |
|------------------|---------------------|----------------------------------|
| Files            | `kebab-case`        | `recurring-reports.service.ts`   |
| Classes          | `PascalCase`        | `RecurringReportsService`        |
| Variables/props  | `camelCase`         | `accountId`, `createdAt`         |
| Interfaces       | `PascalCase` + `I`  | `IContactRepository`             |
| Enums (name)     | `PascalCase`        | `ReportFrequency`                |
| Enum values      | `UPPER_SNAKE_CASE`  | `WEEKLY`, `MONTHLY`              |
| Constants        | `UPPER_SNAKE_CASE`  | `MAX_RETRY_COUNT`                |
| DB columns       | `snake_case`        | `account_id`, `created_at`       |
| Route paths      | `kebab-case`        | `v1/recurring-reports`           |

**Project prefix:** every public class carries the project prefix. Examples use `Dcm`.

```typescript
// Good
export class DcmRecurringReportsService { ... }
export class DcmRecurringReportEntity { ... }

// Bad - no prefix, collision risk in a monorepo
export class RecurringReportsService { ... }
```

## 3. Modules

```typescript
@Module({
    imports: [
        TypeOrmModule.forFeature(DcmRecurringReportsModule.entities),
        DcmIdCoreModule,           // auth context
        DcmDriveModule,            // peer feature dependency
    ],
    providers: [
        DcmRecurringReportsService,
        DcmRecurringReportsQueue,
        DcmRecurringReportsFolderDeleteListener,
    ],
    controllers: [DcmRecurringReportsController],
    exports: [DcmRecurringReportsService],   // only export what consumers need
})
export class DcmRecurringReportsModule {
    static entities = [DcmRecurringReportEntity];
}
```

**Rules:**
- Declare `static entities = [...]` on every module that owns database entities. This allows the central ORM config to aggregate them without importing the module itself.
- Export only what other modules need. Keep your public API minimal.
- Don't import feature modules into `_shared` modules. `_shared` has zero upward dependencies.
- Register queue workers inside the module that owns the domain, not in `CoreModule`.

## 4. Controllers

Controllers handle routing and request/response mapping only. No business logic.

```typescript
@Controller({
    path: 'v1/recurring-reports',
    scope: Scope.REQUEST,       // use REQUEST scope when injecting request-scoped deps
})
@UsePipes(new ValidationPipe({ transform: true }))
@AuthenticatedOnly([DcmChannelType.Api, DcmChannelType.Web])
export class DcmRecurringReportsController {

    constructor(
        private readonly recurringReportsService: DcmRecurringReportsService,
    ) {}

    @Get()
    @AuthorizeForUserRoles({ permissions: [DcmIdPermission.RunReports] })
    getReports(@CurrentAccount() account: DcmIdAccount): Promise<DcmRecurringReportEntity[]> {
        return this.recurringReportsService.getReports(account.uuid);
    }

    @Post()
    @CreateEvent({ category: DcmCoreEventCategory.Reports, type: DcmCoreEventType.Create })
    createReport(
        @CurrentUser() user: DcmIdUser,
        @Body() body: DcmRecurringReportCreateDto,
    ): Promise<DcmRecurringReportEntity> {
        return this.recurringReportsService.createReport(body, user);
    }

    @Delete(':uuid')
    deleteReport(
        @CurrentUser() user: DcmIdUser,
        @Param('uuid') uuid: string,
    ): Promise<void> {
        return this.recurringReportsService.deleteReport(uuid, user);
    }
}
```

**Rules:**
- Apply `@UsePipes(new ValidationPipe({ transform: true }))` at controller level so all endpoints validate and transform inputs.
- Use `@CurrentUser()` and `@CurrentAccount()` parameter decorators. Never read from `request` directly.
- Return the service promise directly. Do not `await` in controllers unless you need the value.
- Keep route handlers to 1-3 lines. If you need more, move the logic to the service.
- Declare `static excludedEndpointsFromGlobalPrefix` when a controller has routes outside the global prefix.

## 5. Services

Services own all business logic, data access, and domain rule enforcement.

```typescript
@Injectable()
export class DcmContactService {

    private readonly contactRepository: Repository<DcmContact> & typeof dcmContactRepository;

    constructor(
        @InjectRepository(DcmContact) contactRepository: Repository<DcmContact>,
        private readonly accountsService: DcmIdAccountsService,
        private readonly permissionService: DcmIdPermissionService,
        private readonly eventEmitter: EventEmitter2,
    ) {
        // Extend repository with custom query methods at construction time
        this.contactRepository = contactRepository.extend(dcmContactRepository);
    }

    async createContact(body: DcmContactCreateDto, user: DcmIdUser): Promise<DcmContact> {
        const [contact] = await this.createContactsBulk([body], user);
        return contact;
    }

    async updateContact(
        contactId: string,
        body: DcmContactUpdateDto,
        user: DcmIdUser,
    ): Promise<DcmContact> {
        const contact = await this.contactRepository.findOneByOrFail({ uuid: Equal(contactId) });
        await this.assertContactAccess(contact, user);
        Object.assign(contact, body);
        return contact.save();
    }

    // Private helper - access control check kept close to the usage
    private async assertContactAccess(contact: DcmContact, user: DcmIdUser): Promise<void> {
        if (contact.accountId !== user.accountId) {
            throw new ForbiddenException('Contact does not belong to your account');
        }
    }
}
```

**Rules:**
- One responsibility per method. Split `createAndNotify` into `create` + `notify`.
- Use `findOneByOrFail` (throws `EntityNotFoundError`) instead of `findOneBy` + manual null check.
- Prefix private guard/assertion helpers with `assert` so intent is clear.
- Emit domain events via `EventEmitter2`, not from controllers.
- Inject `DataSource` (named connection) only when you need raw queries or transactions that span multiple repositories.
- Never `catch` and swallow errors silently. Log and rethrow, or convert to a typed HTTP exception.

## 6. DTOs & Validation

DTOs enforce the contract at the boundary. Use `class-validator` + `class-transformer`.

```typescript
// create-contact.dto.ts
export class DcmContactCreateDto {

    @IsString()
    name: string;

    @IsOptional()
    @IsEmail()
    @Transform(({ value }) => value?.toLowerCase().trim())
    email?: string;

    @IsOptional()
    @IsPhoneNumber()
    @Transform(({ value }) => value?.replace(/[^+0-9.]/g, ''))
    phoneNumber?: string;
}

// update-contact.dto.ts - re-use create DTO, make all fields optional
export class DcmContactUpdateDto extends DcmContactCreateDto {
    @IsOptional()
    declare name: string;   // override parent's required field
}

// list-contact.dto.ts - query params always extend shared pagination
export class DcmContactListDto extends DcmSharedPaginationDto {
    @IsOptional()
    @IsString()
    query?: string;

    @IsOptional()
    @IsBoolean()
    @Transform(({ value }) => value === 'true' || value === true)
    createdByMe?: boolean;
}

// _shared/dtos/pagination.dto.ts
export class DcmSharedPaginationDto {
    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(0)
    offset: number = 0;

    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(5)
    @Max(500)
    limit: number = 50;
}
```

**Rules:**
- `@Transform` before `@Is*` validators. Transformation runs first when `transform: true` is set.
- Extend `DcmSharedPaginationDto` for any list/query DTO that supports paging.
- Use `declare` (not re-assignment) to override inherited fields in DTO subclasses.
- Never reuse a DTO across multiple unrelated operations. Create specific DTOs per operation.
- DTOs live in a `dtos/` sub-folder for modules with multiple, or inline in `feature.dto.ts` for simple ones.
- Apply `@Type(() => Number)` to numeric query params. HTTP delivers strings.

## 7. Entities & Repositories

#### Entities

```typescript
@Entity('recurring_reports')
export class DcmRecurringReportEntity extends DcmAuditable {

    @PrimaryGeneratedColumn('uuid')
    uuid: string;

    @ManyToOne(() => DcmIdAccount)
    @JoinColumn({ name: 'account_id' })
    account: Relation<DcmIdAccount>;

    @Column({ name: 'account_id', type: 'uuid', nullable: false })
    accountId: string;

    @Column({ type: 'enum', enum: DcmRecurringReportFrequency, nullable: false })
    frequency: DcmRecurringReportFrequency;
}

// _shared/entities/auditable.ts - extend this for every entity
export abstract class DcmAuditable extends BaseEntity {
    @CreateDateColumn({ name: 'created_at', type: 'timestamp', nullable: false })
    createdAt!: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamp', nullable: true })
    updatedAt!: Date | null;
}
```

**Rules:**
- All entities extend `DcmAuditable` unless there's an explicit reason not to.
- Always include both the relation (`account`) and the FK column (`accountId`) so you can query by FK without joining.
- Use `Relation<T>` for relation types. It avoids circular dependency issues at runtime.
- Use `snake_case` for column `name` and table `name`. TypeORM's auto-naming is inconsistent across versions.
- Never put business logic in entities. Keep them as pure data containers.

#### Repository Extensions

Use TypeORM's `.extend()` pattern for complex queries. Don't create separate `@Injectable()` repository classes.

```typescript
// entities/contact.repository.ts
export interface IContactRepository<T = DcmContact> {
    getContacts(user: DcmIdUser, options: DcmContactListDto): Promise<{ rows: T[]; count: number }>;
}

export const dcmContactRepository = {
    async getContacts(
        this: Repository<DcmContact> & IContactRepository,
        user: DcmIdUser,
        options: DcmContactListDto,
    ): Promise<{ rows: DcmContact[]; count: number }> {
        const [rows, count] = await this
            .createQueryBuilder('contact')
            .where('contact.accountId = :accountId', { accountId: user.accountId })
            .take(options.limit)
            .skip(options.offset)
            .getManyAndCount();
        return { rows, count };
    },
};

// In service constructor:
this.contactRepository = contactRepository.extend(dcmContactRepository);
```

**Rules:**
- Define a matching `I*Repository` interface so TypeScript can type-check `this` inside repository methods.
- Repository method objects are plain objects. No classes or decorators here.
- Complex queries with `createQueryBuilder` always belong in repository extensions, not services.
- Use `getManyAndCount()` for paginated list endpoints: one query, two results.

## 8. Guards & Authorization

#### Authentication

Apply a global authentication guard via `APP_GUARD`. Don't repeat `@UseGuards()` on every controller.

```typescript
// In app bootstrap or CoreModule providers:
{ provide: APP_GUARD, useClass: DcmIdAuthenticationGuard }
```

Mark public routes with a decorator:

```typescript
@Public()          // skips authentication guard
@Get('ping')
ping() { return 'ok'; }
```

#### Authorization

```typescript
// On controller - applies to all routes in this controller
@AuthenticatedOnly([DcmChannelType.Api, DcmChannelType.Web])

// On individual route - fine-grained role/permission check
@AuthorizeForUserRoles({
    roles: [DcmIdUserRole.owner, DcmIdUserRole.superadmin],
    permissions: [DcmIdPermission.RunReports],
})
@Get('reports')
getReports() { ... }
```

#### Parameter Decorators

Typed parameter decorators for auth context. Never read `req.user` directly.

```typescript
export const CurrentUser = createParamDecorator(
    (_data: unknown, ctx: ExecutionContext) =>
        ctx.switchToHttp().getRequest()[REQUEST_USER] ?? null,
);

export const CurrentAccount = createParamDecorator(
    (_data: unknown, ctx: ExecutionContext) =>
        ctx.switchToHttp().getRequest()[REQUEST_ACCOUNT] ?? null,
);
```

**Rules:**
- Authentication and authorization are separate concerns, so separate guards.
- Guards throw standard HTTP exceptions (`UnauthorizedException`, `ForbiddenException`), never return `false`.
- Populate all auth context onto the request object in the authentication guard, not in individual controllers.
- Use `Reflector` to read decorator metadata inside guards and interceptors. Don't pass data via the constructor.

## 9. Interceptors & Pipes

#### Interceptors

```typescript
@Injectable({ scope: Scope.REQUEST })
export class DcmCoreEventsInterceptor implements NestInterceptor {

    constructor(
        private readonly reflector: Reflector,
        private readonly eventsService: DcmCoreEventsService,
    ) {}

    intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
        const startTime = Date.now();
        const request: Request = context.switchToHttp().getRequest();

        return next.handle().pipe(
            tap(() => {
                const meta = this.reflector.get(CREATE_EVENT_KEY, context.getHandler());
                if (meta) {
                    this.eventsService.emit({ ...meta, duration: Date.now() - startTime });
                }
            }),
        );
    }
}
```

#### Pipes

```typescript
@Injectable()
export class DcmTransformBodyToArrayPipe implements PipeTransform<object, object[]> {
    transform(value: object | object[]): object[] {
        return Array.isArray(value) ? value : [value];
    }
}

// Usage:
@Post('bulk')
createBulk(@Body(DcmTransformBodyToArrayPipe) bodies: DcmContactCreateDto[]) { ... }
```

**Rules:**
- Use `Scope.REQUEST` on interceptors that inject request-scoped providers.
- Register cross-cutting interceptors (logging, events) globally via `APP_INTERCEPTOR`.
- Apply `ValidationPipe` at controller class level, not per-route, unless a route needs different options.
- Custom pipes are for **shape transformation** (array wrapping, string splitting). Validation stays in DTOs.

## 10. Exception Handling

#### Use standard NestJS exceptions first

```typescript
// Good - standard exceptions map directly to HTTP status codes
throw new NotFoundException(`Report ${uuid} not found`);
throw new BadRequestException('Limit must be between 1 and 500');
throw new ForbiddenException('You do not have access to this resource');
throw new UnauthorizedException('Authentication required');
throw new ConflictException('A contact with this email already exists');
```

#### Create domain exceptions for reusable error scenarios

```typescript
// two-factor.exceptions.ts
export class DcmTwoFactorCodeRequiredException extends ForbiddenException {
    constructor() {
        super('Two-factor verification code is required');
    }
}

export class DcmTwoFactorCodeInvalidException extends ForbiddenException {
    constructor(code: string) {
        super(`Verification code '${code}' is not valid`);
    }
}
```

**Rules:**
- Never `throw new Error(...)` in application code. Always use a typed NestJS or domain exception.
- Exception messages must be user-readable. They surface in API responses.
- Domain exceptions live in an `exceptions/` folder inside the feature module.
- Don't create a domain exception for a one-off throw. Use the standard class.
- Don't use a global `try-catch` exception filter to swallow errors. Let NestJS's built-in filter handle formatting.

## 11. Events & Queues

#### Domain Events

```typescript
// Emit from service after mutation
this.eventEmitter.emit(DcmContactEvents.Created, new DcmContactCreatedEvent(contact));

// Listen in a dedicated listener class
@Injectable()
export class DcmContactCreatedListener {
    @OnEvent(DcmContactEvents.Created)
    async handle(event: DcmContactCreatedEvent): Promise<void> {
        await this.notificationService.notifyContactAdded(event.contact);
    }
}
```

#### Queue Jobs (BullMQ)

```typescript
@Injectable()
@Processor(DCM_RECURRING_REPORTS_QUEUE_NAME, DefaultQueueWorkerOptions)
export class DcmRecurringReportsQueue extends WorkerHost {

    private readonly logger = new Logger(DcmRecurringReportsQueue.name);

    constructor(
        @InjectRepository(DcmRecurringReportEntity) private readonly reportsRepo: ...,
        private readonly recurringReportsService: DcmRecurringReportsService,
    ) {
        super();
    }

    async process(job: Job<DcmRecurringReportEntity>): Promise<void> {
        const report = await this.reportsRepo.findOneBy({ uuid: job.data.uuid });
        if (!report) {
            this.logger.warn(`Report ${job.data.uuid} not found - skipping`);
            return;
        }
        await this.recurringReportsService.send(report);
    }

    @OnWorkerEvent('error')
    onError(error: Error): void {
        this.logger.error('Worker error', error.stack);
    }

    @OnWorkerEvent('failed')
    onFailed(job: Job, error: Error): void {
        this.logger.error(`Job ${job.id} failed: ${error.message}`, error.stack);
    }
}
```

**Rules:**
- Queue processors extend `WorkerHost` and are registered in the owning feature module.
- Re-fetch the entity inside the processor. Job data may be stale.
- Handle `error` and `failed` worker events explicitly. Log every failure.
- Queue name constants go in `feature-name.interfaces.ts` as `UPPER_SNAKE_CASE` exports.

## 12. Configuration

Centralize all environment-dependent configuration in a config factory. Never read `process.env` directly in services or controllers.

```typescript
// config/database.config.ts
export const dcmSqlConfigFactory = (type: 'mysql' | 'pgsql'): TypeOrmModuleOptions => ({
    type,
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT),
    username: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    synchronize: false,             // never true in production
    logging: process.env.NODE_ENV === 'development',
});
```

**Rules:**
- `synchronize: false` always. Use migrations.
- Config factories are pure functions that return plain objects. No NestJS decorators.
- Access config in services via injected `ConfigService`, not via the factory directly.
- Environment-specific overrides go in `.env.development`, `.env.test`, `.env.production`.

## 13. Testing

```typescript
describe('DcmRecurringReportsService', () => {

    let service: DcmRecurringReportsService;
    let reportsRepo: jest.Mocked<Repository<DcmRecurringReportEntity>>;

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                DcmRecurringReportsService,
                {
                    provide: getRepositoryToken(
                        DcmRecurringReportEntity,
                        DcmDatabaseConnectionName.mysql,
                    ),
                    useValue: {
                        find: jest.fn(),
                        findOneBy: jest.fn(),
                        save: jest.fn(),
                    },
                },
            ],
        }).compile();

        service = module.get(DcmRecurringReportsService);
        reportsRepo = module.get(
            getRepositoryToken(DcmRecurringReportEntity, DcmDatabaseConnectionName.mysql),
        );
    });

    describe('getReports', () => {
        it('returns reports for the account', async () => {
            const reports = [{ uuid: 'abc' }] as DcmRecurringReportEntity[];
            reportsRepo.find.mockResolvedValue(reports);
            const result = await service.getReports('account-id');
            expect(result).toEqual(reports);
        });

        it('returns empty array when no reports exist', async () => {
            reportsRepo.find.mockResolvedValue([]);
            const result = await service.getReports('account-id');
            expect(result).toHaveLength(0);
        });
    });
});
```

**Rules:**
- Test files live alongside source: `feature.service.spec.ts` next to `feature.service.ts`.
- Use `getRepositoryToken(Entity, connectionName)`. A named connection requires the second argument.
- Mock only what the unit under test calls. Don't mock the entire module.
- Test the public interface, not implementation details.
- Name test cases as sentences: `'returns reports for the account'`, not `'should work'`.
- Prefer `describe` blocks per method over one flat list of `it` blocks.

## 14. Logging

Use NestJS's built-in `Logger`. Instantiate once per class with the class name as context.

```typescript
@Injectable()
export class DcmRecurringReportsService {

    private readonly logger = new Logger(DcmRecurringReportsService.name);

    async send(report: DcmRecurringReportEntity): Promise<void> {
        this.logger.log(`Sending report ${report.uuid}`);
        try {
            // ...
            this.logger.log(`Report ${report.uuid} sent successfully`);
        } catch (error) {
            this.logger.error(`Failed to send report ${report.uuid}`, error.stack);
            throw error;
        }
    }
}
```

| Level      | When to use                                               |
|------------|-----------------------------------------------------------|
| `log`      | Normal operations, lifecycle events                       |
| `warn`     | Unexpected but recoverable, for example an entity missing from a queue |
| `error`    | Exceptions and failures. Always include `error.stack`     |
| `debug`    | Detailed diagnostic info. Disabled in production          |
| `verbose`  | Very fine-grained tracing. Development only               |

**Rules:**
- Always pass `error.stack` as the second argument to `logger.error()`.
- Don't log sensitive data (passwords, tokens, PII).
- Log at the point of failure, not in every caller up the chain.
- Use `debug` for high-frequency events (per-request, per-message) that are too noisy for `log`.

## 15. Code Style

#### Formatting
- **Indentation:** 4 spaces (match the existing codebase)
- **Quotes:** Single quotes
- **Semicolons:** Required
- **Trailing commas:** Required in multiline arrays/objects
- **Max line length:** 120 characters

#### Imports

Order imports in three groups, separated by a blank line:

```typescript
// 1. Node built-ins
import * as path from 'path';

// 2. Third-party packages
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

// 3. Internal modules (absolute paths via tsconfig paths)
import { DcmIdUser } from '@dcm/identity';
import { DcmSharedPaginationDto } from '../_shared/dtos/pagination.dto';
```

#### TypeScript
- Prefer `const` over `let`. Never use `var`.
- Avoid `any`. Use `unknown` for truly unknown types and narrow with type guards.
- Use `!` non-null assertion only when you can prove the value exists. Add a comment why.
- Prefer `async/await` over raw promise chains.
- Use `Partial<T>`, `Pick<T, K>`, `Omit<T, K>` over re-declaring shapes.

#### General
- Methods do one thing. If a method name contains "and", split it.
- Private methods that guard access start with `assert` (`assertContactAccess`).
- Don't export things that aren't used outside the file.
- No magic numbers. Extract them to named constants.
- No commented-out code in committed files.

## Quick Reference

```
Feature        → {name}.module.ts, .controller.ts, .service.ts, .entity.ts, .dto.ts
Shared         → _shared/{dtos,pipes,guards,interceptors,entities}/
Utils          → _utils/ (pure functions, no DI)
Migrations     → _migrations/{mysql,pgsql}/
Naming         → Dcm prefix on all public classes
DB columns     → snake_case; entity props → camelCase
DTOs           → one per operation (Create, Update, List); extend DcmSharedPaginationDto for lists
Exceptions     → standard NestJS classes; domain exceptions only if reused across controllers
Logging        → Logger per class; always log error.stack
Tests          → .spec.ts next to source; getRepositoryToken(Entity, connectionName)
```
